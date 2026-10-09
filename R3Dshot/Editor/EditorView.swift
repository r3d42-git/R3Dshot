import SwiftUI

struct EditorView: View {
    @Bindable var store: EditorStore
    let onSave: () -> Void
    let onSaveAs: () -> Void
    let onCopyRenderedImage: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            EditorToolPalette(store: store)
            Divider()
            VStack(spacing: 0) {
                EditorCanvasView(store: store)
                Divider()
                statusBar
            }
        }
        .background(Color(nsColor: EditorAppearance.panel))
        .toolbarBackground(Color(nsColor: EditorAppearance.titlebar), for: .windowToolbar)
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    store.undoManager.undo()
                } label: {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                }
                .disabled(!store.undoManager.canUndo)
                .help("Rückgängig (⌘Z)")

                Button {
                    store.undoManager.redo()
                } label: {
                    Label("Wiederholen", systemImage: "arrow.uturn.forward")
                }
                .disabled(!store.undoManager.canRedo)
                .help("Wiederholen (⇧⌘Z)")

                editMenu
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: onCopyRenderedImage) {
                    Label("Bild kopieren", systemImage: "photo.on.rectangle")
                }
                .labelStyle(.titleAndIcon)
                .help("Bearbeitetes Bild in die Zwischenablage kopieren")

                Button(action: onSave) {
                    Label("Sichern", systemImage: "square.and.arrow.down")
                }
                .labelStyle(.titleAndIcon)
                .keyboardShortcut("s", modifiers: .command)
                .help("Bearbeitetes Bild sichern (⌘S)")

                Menu {
                    Button("Sichern unter …", action: onSaveAs)
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                } label: {
                    Label("Weitere Sicherungsoptionen", systemImage: "chevron.down")
                }
                .menuIndicator(.hidden)
                .help("Sichern unter … (⇧⌘S)")

                Button {
                    store.isInspectorPresented.toggle()
                } label: {
                    Label("Eigenschaften", systemImage: "sidebar.trailing")
                }
                .help("Eigenschaften ein- oder ausblenden")
            }
        }
        .inspector(isPresented: $store.isInspectorPresented) {
            RectangleInspectorView(store: store)
                .inspectorColumnWidth(min: 260, ideal: 280, max: 340)
        }
    }

    private var editMenu: some View {
        Menu {
            Button("Auswahl kopieren") { store.copySelection() }
                .disabled(!store.hasSelection)
            Button("Elemente einsetzen") { store.paste() }
            Button("Auswahl duplizieren") { store.duplicateSelection() }
                .disabled(!store.hasSelection)
            Divider()
            Button("Auswahl löschen", role: .destructive) { store.deleteSelection() }
                .disabled(!store.hasSelection)
            if store.activeTool == .crop {
                Divider()
                Button("Zuschnitt zurücksetzen") { store.resetCrop() }
            }
        } label: {
            Label("Bearbeiten", systemImage: "ellipsis.circle")
        }
        .help("Auswahl kopieren, einsetzen, duplizieren oder löschen")
    }

    private var statusBar: some View {
        VStack(spacing: 5) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Text(documentSizeDescription)
                        .fixedSize()
                    Spacer(minLength: 6)
                    zoomControls
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(documentSizeDescription)
                    zoomControls
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 6) {
                Image(systemName: store.feedbackMessage == nil ? store.activeTool.systemImage : "info.circle")
                Text(store.feedbackMessage ?? interactionHint)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .help(store.feedbackMessage ?? interactionHint)
            .accessibilityElement(children: .combine)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var zoomControls: some View {
        HStack(spacing: 7) {
            Button(action: store.zoomOut) {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Verkleinern")
            Text("\(Int((store.effectiveZoom * 100).rounded())) %")
                .monospacedDigit()
                .frame(minWidth: 42)
                .accessibilityLabel("Zoom \(Int((store.effectiveZoom * 100).rounded())) Prozent")
            Button(action: store.zoomIn) {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Vergrößern")
            Divider().frame(height: 14)
            Button("Anpassen", action: store.fitCanvas)
                .foregroundStyle(store.isZoomFitted ? Color.accentColor : Color.primary)
                .help("Den gesamten Ausschnitt im Fenster anzeigen")
                .accessibilityAddTraits(store.isZoomFitted ? .isSelected : [])
            Button("100 %", action: store.showActualSize)
                .help("Ein Bildpixel als einen Bildschirmpixel anzeigen")
        }
        .buttonStyle(.borderless)
        .fixedSize()
    }

    private var documentSizeDescription: String {
        let crop = store.document.crop.clamped(to: store.document.original.pixelSize).boundsInCanvasPixels
        return "\(max(1, Int(crop.width.rounded()))) × \(max(1, Int(crop.height.rounded()))) px"
    }

    private var interactionHint: String {
        if store.activeTool == .select, store.hasSelection {
            if store.selectionCount > 1 {
                return "\(store.selectionCount) Elemente ausgewählt · gemeinsam verschieben · ⌘-Klick ändert die Auswahl"
            }
            return "\(store.selectedShapeTitle ?? "Element") ausgewählt · ziehen zum Verschieben · Griffe zum Skalieren"
        }
        switch store.activeTool {
        case .select: return "Element anklicken · ⌘-Klick für Mehrfachauswahl"
        case .crop: return "Ausschnitt aufziehen · Griffe zum Anpassen · Verhältnis in den Eigenschaften"
        case .rectangle: return "Rechteck aufziehen · Farbe und Kontur in den Eigenschaften"
        case .ellipse: return "Ellipse aufziehen · Farbe und Kontur in den Eigenschaften"
        case .arrow: return "Vom Startpunkt zur Pfeilspitze ziehen"
        case .marker: return "Ziehen zum Hervorheben · horizontaler Strich rastet ein"
        case .text: return "Textbereich aufziehen · Text in den Eigenschaften bearbeiten"
        case .speechBubble: return "Sprechblase aufziehen · Text und Zeiger in den Eigenschaften bearbeiten"
        case .stepNumber: return "Klicken, um den nächsten Schritt zu setzen"
        case .redaction: return "Bereich aufziehen, um ihn im exportierten Bild zu schwärzen"
        case .pixelate: return "Bereich aufziehen · Pixelgröße in den Eigenschaften anpassen"
        case .focus: return "Bereich aufziehen · das Umfeld wird weichgezeichnet"
        }
    }
}
