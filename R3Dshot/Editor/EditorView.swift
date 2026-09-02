import SwiftUI

struct EditorView: View {
    @Bindable var store: EditorStore
    let onSave: () -> Void
    let onSaveAs: () -> Void
    let onCopyRenderedImage: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EditorCanvasView(store: store)

            Divider()

            HStack(spacing: 12) {
                Text(store.document.original.pixelSize.pixelSizeDescription)
                Spacer()
                Button {
                    store.zoom = max(0.25, store.zoom - 0.25)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.plain)
                .help("Verkleinern")

                Text("Anpassen · \(Int(store.zoom * 100)) %")
                    .monospacedDigit()
                    .frame(width: 112)

                Button {
                    store.zoom = min(4, store.zoom + 0.25)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.plain)
                .help("Vergrößern")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .frame(height: 30)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                ControlGroup {
                    ForEach(EditorTool.allCases) { tool in
                        Toggle(
                            isOn: Binding(
                                get: { store.activeTool == tool },
                                set: { isSelected in
                                    if isSelected {
                                        store.activeTool = tool
                                    }
                                }
                            )
                        ) {
                            Label(tool.title, systemImage: tool.systemImage)
                        }
                        .toggleStyle(.button)
                        .help(tool.helpText)
                    }
                }
                .labelStyle(.iconOnly)
            }

            ToolbarItemGroup(placement: .automatic) {
                Button {
                    store.undoManager.undo()
                } label: {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!store.undoManager.canUndo)
                .help("Rückgängig (⌘Z)")

                Button {
                    store.undoManager.redo()
                } label: {
                    Label("Wiederholen", systemImage: "arrow.uturn.forward")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!store.undoManager.canRedo)
                .help("Wiederholen (⇧⌘Z)")
            }

            ToolbarItemGroup(placement: .automatic) {
                Button {
                    store.copySelection()
                } label: {
                    Label("Element kopieren", systemImage: "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(store.selectedElement == nil)
                .help("Ausgewähltes Element kopieren (⌘C)")

                Button {
                    store.paste()
                } label: {
                    Label("Element einsetzen", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: .command)
                .help("Kopiertes Element einsetzen (⌘V)")

                Button(role: .destructive) {
                    store.deleteSelection()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(store.selectedElement == nil)
                .help("Ausgewähltes Element löschen (⌫)")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: onCopyRenderedImage) {
                    Label("Bild kopieren", systemImage: "photo.on.rectangle")
                }
                .help("Bearbeitetes Bild in die Zwischenablage kopieren")

                Button(action: onSaveAs) {
                    Label("Sichern unter …", systemImage: "square.and.arrow.down")
                }
                .help("Bearbeitetes Bild unter einem neuen Namen sichern")

                Button(action: onSave) {
                    Label("Sichern", systemImage: "square.and.arrow.down.fill")
                }
                .keyboardShortcut("s", modifiers: .command)
                .help("Bearbeitetes Bild sichern (⌘S)")

                Button {
                    store.isInspectorPresented.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Inspector ein- oder ausblenden")
            }
        }
        .inspector(isPresented: $store.isInspectorPresented) {
            RectangleInspectorView(store: store)
                .inspectorColumnWidth(min: 250, ideal: 280, max: 340)
        }
    }
}

private extension PixelSize {
    var pixelSizeDescription: String {
        "\(width) × \(height) px"
    }
}
