import AppKit
import SwiftUI

@MainActor
final class QuickActionPanelController {
    private let fileStore: ScreenshotFileStore
    private let captureStore: PendingCaptureStore
    private let preferences: PreferencesStore
    private let openEditor: (PendingCapture) -> Void
    private let onCaptureRemoved: () -> Void
    private var panels: [UUID: NSPanel] = [:]

    init(
        fileStore: ScreenshotFileStore,
        captureStore: PendingCaptureStore,
        preferences: PreferencesStore,
        openEditor: @escaping (PendingCapture) -> Void,
        onCaptureRemoved: @escaping () -> Void
    ) {
        self.fileStore = fileStore
        self.captureStore = captureStore
        self.preferences = preferences
        self.openEditor = openEditor
        self.onCaptureRemoved = onCaptureRemoved
    }

    func show(_ capture: PendingCapture) {
        let panel = makePanel(for: capture)
        panels[capture.id] = panel
        position(panel, index: panels.count - 1)
        panel.orderFrontRegardless()
    }

    private func makePanel(for capture: PendingCapture) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 308, height: 282),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let view = QuickActionView(
            capture: capture,
            suggestedFileName: fileStore.suggestedFileName(for: capture, preferences: preferences),
            onSave: { [weak self] in self?.save(capture) },
            onSaveAs: { [weak self] in self?.saveAs(capture) },
            onCopy: { [weak self] in self?.copy(capture) },
            onOpenEditor: { [weak self] in self?.open(capture) },
            onDiscard: { [weak self] in self?.discard(capture) }
        )
        panel.contentView = NSHostingView(rootView: view)
        return panel
    }

    private func position(_ panel: NSPanel, index: Int) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let offset = CGFloat(index % 3) * 18
        panel.setFrameOrigin(
            NSPoint(
                x: frame.maxX - panel.frame.width - 22 - offset,
                y: frame.minY + 22 + offset
            )
        )
    }

    private func save(_ capture: PendingCapture) {
        do {
            _ = try fileStore.saveDefault(capture, preferences: preferences)
            close(capture)
        } catch {
            present(error)
        }
    }

    private func saveAs(_ capture: PendingCapture) {
        do {
            if try fileStore.saveAs(capture, preferences: preferences) != nil {
                close(capture)
            }
        } catch {
            present(error)
        }
    }

    private func copy(_ capture: PendingCapture) {
        do {
            try fileStore.copyToPasteboard(capture)
            close(capture)
        } catch {
            present(error)
        }
    }

    private func open(_ capture: PendingCapture) {
        openEditor(capture)
        close(capture)
    }

    private func discard(_ capture: PendingCapture) {
        close(capture)
    }

    private func close(_ capture: PendingCapture) {
        panels.removeValue(forKey: capture.id)?.close()
        captureStore.remove(capture)
        onCaptureRemoved()
    }

    private func present(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
