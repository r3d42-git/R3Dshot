import AppKit
import SwiftUI

@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    private struct OpenEditor {
        let window: NSWindow
        let store: EditorStore
    }

    private let fileStore: ScreenshotFileStore
    private let preferences: PreferencesStore
    private let onEditorsChanged: () -> Void
    private var editors: [UUID: OpenEditor] = [:]
    private var lastActiveEditorID: UUID?

    init(
        fileStore: ScreenshotFileStore,
        preferences: PreferencesStore,
        onEditorsChanged: @escaping () -> Void
    ) {
        self.fileStore = fileStore
        self.preferences = preferences
        self.onEditorsChanged = onEditorsChanged
    }

    var hasOpenEditors: Bool {
        !editors.isEmpty
    }

    func open(_ capture: PendingCapture) {
        if let editor = editors[capture.id] {
            editor.window.makeKeyAndOrderFront(nil)
            activateApplication()
            return
        }

        let store = EditorStore(capture: capture)
        let rootView = EditorView(
            store: store,
            onSave: { [weak self, weak store] in
                guard let self, let store else { return }
                save(store)
            },
            onSaveAs: { [weak self, weak store] in
                guard let self, let store else { return }
                saveAs(store)
            },
            onCopyRenderedImage: { [weak self, weak store] in
                guard let self, let store else { return }
                copyRenderedImage(store)
            }
        )
        let controller = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: controller)
        window.identifier = NSUserInterfaceItemIdentifier(capture.id.uuidString)
        window.title = "R3Dshot – Editor"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 720, height: 480)
        window.toolbarStyle = .unified
        window.tabbingMode = .preferred
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.setFrame(initialFrame(), display: false)
        editors[capture.id] = OpenEditor(window: window, store: store)
        lastActiveEditorID = capture.id
        onEditorsChanged()
        window.makeKeyAndOrderFront(nil)
        activateApplication()
    }

    func focusMostRecentEditor() {
        let editor = lastActiveEditorID.flatMap { editors[$0] } ?? editors.values.first
        guard let editor else { return }
        editor.window.makeKeyAndOrderFront(nil)
        activateApplication()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let editor = editors.values.first(where: { $0.window === sender }),
              editor.store.hasUnsavedChanges
        else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Änderungen sichern?"
        alert.informativeText = "Der Screenshot und seine Änderungen gehen beim Schließen verloren."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Sichern")
        alert.addButton(withTitle: "Verwerfen")
        alert.addButton(withTitle: "Abbrechen")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return save(editor.store)
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        editors = editors.filter { $0.value.window !== window }
        if lastActiveEditorID.flatMap({ editors[$0] }) == nil {
            lastActiveEditorID = editors.keys.first
        }
        onEditorsChanged()

        if editors.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = editors.first(where: { $0.value.window === window })?.key
        else { return }
        lastActiveEditorID = id
    }

    private func activateApplication() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func initialFrame() -> NSRect {
        let visibleFrame = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let margin: CGFloat = 40
        let width = min(1600, max(720, visibleFrame.width - margin * 2))
        let height = min(960, max(480, visibleFrame.height - margin * 2))

        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func renderedImage(for store: EditorStore) throws -> CGImage {
        try ScreenshotRenderer.render(
            document: store.document,
            originalImage: store.session.originalImage
        )
    }

    @discardableResult
    private func save(_ store: EditorStore) -> Bool {
        do {
            let image = try renderedImage(for: store)
            let destination: URL
            if let savedURL = store.savedURL {
                try fileStore.save(image, to: savedURL)
                destination = savedURL
            } else {
                destination = try fileStore.saveDefault(
                    image: image,
                    capturedAt: store.session.capturedAt,
                    preferences: preferences
                )
            }
            store.markSaved(at: destination)
            return true
        } catch {
            present(error)
            return false
        }
    }

    private func saveAs(_ store: EditorStore) {
        do {
            let image = try renderedImage(for: store)
            if let destination = try fileStore.saveAs(
                image: image,
                capturedAt: store.session.capturedAt,
                preferences: preferences
            ) {
                store.markSaved(at: destination)
            }
        } catch {
            present(error)
        }
    }

    private func copyRenderedImage(_ store: EditorStore) {
        do {
            try fileStore.copyToPasteboard(renderedImage(for: store))
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        NSAlert(error: error).runModal()
    }
}
