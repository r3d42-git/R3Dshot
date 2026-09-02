import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    let shortcuts: ShortcutStore
    let onShortcutRecordingChanged: (Bool) -> Void

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("Allgemein", systemImage: "gearshape")
                }

            ShortcutSettingsView(
                shortcuts: shortcuts,
                onShortcutRecordingChanged: onShortcutRecordingChanged
            )
                .tabItem {
                    Label("Kurzbefehle", systemImage: "keyboard")
                }

            captureTab
                .tabItem {
                    Label("Aufnahme", systemImage: "viewfinder")
                }
        }
        .frame(width: 520, height: 360)
        .padding(20)
    }

    private var generalTab: some View {
        Form {
            Section("Speichern") {
                LabeledContent("Standardordner") {
                    HStack(spacing: 8) {
                        Text(preferences.saveDirectory.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Ändern …", action: chooseSaveDirectory)
                    }
                }

                Picker("Format", selection: $preferences.fileFormatRawValue) {
                    ForEach(PreferencesStore.FileFormat.allCases) { format in
                        Text(format.displayName).tag(format.rawValue)
                    }
                }

                TextField("Dateinamensschema", text: $preferences.filenamePattern)
                Text("Beispiel: \(preferences.suggestedFilename(for: .now)).png")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Datumsmuster: yyyy, MM, dd, HH, mm und ss. Jeder andere Text bleibt unverändert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Anmeldung") {
                Toggle(
                    "R3Dshot bei Anmeldung starten",
                    isOn: Binding(
                        get: { preferences.launchAtLogin },
                        set: { preferences.setLaunchAtLogin($0) }
                    )
                )

                if let error = preferences.loginItemError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var captureTab: some View {
        Form {
            Section("Bildinhalt") {
                Toggle("Fensterschatten aufnehmen", isOn: $preferences.includeWindowShadow)
                Toggle("Mauszeiger aufnehmen", isOn: $preferences.includeMouseCursor)
            }

            Section("Workflow") {
                Toggle("Quick-Action-Panel nach Aufnahme anzeigen", isOn: $preferences.showsQuickActionPanel)
                Text("Das Quick-Action-Panel kann speichern, einen Speicherort wählen, kopieren, den Editor öffnen oder verwerfen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Screenshot-Ordner wählen"
        panel.prompt = "Auswählen"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = preferences.saveDirectory

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        preferences.saveDirectoryPath = url.path
    }
}

private struct ShortcutSettingsView: View {
    let shortcuts: ShortcutStore
    let onShortcutRecordingChanged: (Bool) -> Void

    @State private var recordingAction: CaptureAction?

    var body: some View {
        Form {
            Section {
                ShortcutRecorderRow(
                    title: "Bereich aufnehmen",
                    action: .area,
                    shortcuts: shortcuts,
                    recordingAction: $recordingAction
                )
                ShortcutRecorderRow(
                    title: "Fenster aufnehmen",
                    action: .window,
                    shortcuts: shortcuts,
                    recordingAction: $recordingAction
                )
                ShortcutRecorderRow(
                    title: "Bildschirm aufnehmen",
                    action: .display,
                    shortcuts: shortcuts,
                    recordingAction: $recordingAction
                )
            } footer: {
                Text("Klicke auf einen Eintrag und drücke die gewünschte Tastenkombination. R3Dshot speichert den von macOS gemeldeten virtuellen Keycode; Print wird daher auch bei abweichenden Tastaturen zuverlässig konfigurierbar.")
            }

            Section {
                Button("Standardbelegung wiederherstellen") {
                    shortcuts.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: recordingAction) { _, newValue in
            onShortcutRecordingChanged(newValue != nil)
        }
        .onDisappear {
            onShortcutRecordingChanged(false)
        }
    }
}

private struct ShortcutRecorderRow: View {
    let title: String
    let action: CaptureAction
    let shortcuts: ShortcutStore
    @Binding var recordingAction: CaptureAction?

    private var isRecording: Binding<Bool> {
        Binding(
            get: { recordingAction == action },
            set: { isRecording in
                if isRecording {
                    recordingAction = action
                } else if recordingAction == action {
                    recordingAction = nil
                }
            }
        )
    }

    var body: some View {
        LabeledContent(title) {
            Button(isRecording.wrappedValue ? "Tastenkombination drücken …" : shortcuts.displayString(for: action)) {
                recordingAction = action
            }
            .frame(minWidth: 178)
            .background(
                ShortcutKeyCaptureView(
                    isRecording: isRecording,
                    onShortcut: { shortcut in
                        _ = shortcuts.setShortcut(shortcut, for: action)
                    }
                )
            )
        }
    }
}

private struct ShortcutKeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onShortcut: (KeyboardShortcut) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isRecording: $isRecording, onShortcut: onShortcut)
    }

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: ShortcutCaptureNSView, context: Context) {
        view.coordinator = context.coordinator

        if isRecording {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        }
    }

    final class Coordinator {
        let isRecording: Binding<Bool>
        let onShortcut: (KeyboardShortcut) -> Void

        init(
            isRecording: Binding<Bool>,
            onShortcut: @escaping (KeyboardShortcut) -> Void
        ) {
            self.isRecording = isRecording
            self.onShortcut = onShortcut
        }

        func consume(_ event: NSEvent) {
            if event.keyCode == 53 {
                isRecording.wrappedValue = false
                return
            }

            let displayName = KeyboardShortcutDisplayName.name(for: event)
            let shortcut = KeyboardShortcut(
                keyCode: UInt32(event.keyCode),
                modifiers: ShortcutModifiers(eventModifiers: event.modifierFlags),
                displayName: displayName
            )
            onShortcut(shortcut)
            isRecording.wrappedValue = false
        }
    }
}

private final class ShortcutCaptureNSView: NSView {
    weak var coordinator: ShortcutKeyCaptureView.Coordinator?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        coordinator?.consume(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        coordinator?.consume(event)
        return true
    }
}

private enum KeyboardShortcutDisplayName {
    static func name(for event: NSEvent) -> String {
        switch event.keyCode {
        case 122: "F1"
        case 120: "F2"
        case 99: "F3"
        case 118: "F4"
        case 96: "F5"
        case 97: "F6"
        case 98: "F7"
        case 100: "F8"
        case 101: "F9"
        case 109: "F10"
        case 103: "F11"
        case 111: "F12"
        case 105: "F13"
        case 107: "F14"
        case 113: "F15"
        case 106: "F16"
        case 64: "F17"
        case 79: "F18"
        case 80: "F19"
        case 90: "F20"
        case 36: "↩"
        case 48: "⇥"
        case 49: "Leertaste"
        case 51: "⌫"
        case 117: "⌦"
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        default:
            event.charactersIgnoringModifiers?.uppercased() ?? "Taste (event.keyCode)"
        }
    }
}
