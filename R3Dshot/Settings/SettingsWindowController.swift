import AppKit
import SwiftUI

/// Owns the on-demand settings window while the application remains a menu-bar
/// accessory. This deliberately does not use the responder-chain Settings
/// command: status-item applications do not have a regular app menu to route
/// that command through reliably.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onVisibilityChanged: (Bool) -> Void

    init(
        preferences: PreferencesStore,
        shortcuts: ShortcutStore,
        onShortcutRecordingChanged: @escaping (Bool) -> Void,
        onVisibilityChanged: @escaping (Bool) -> Void
    ) {
        self.onVisibilityChanged = onVisibilityChanged
        let contentView = SettingsView(
            preferences: preferences,
            shortcuts: shortcuts,
            onShortcutRecordingChanged: onShortcutRecordingChanged
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Einstellungen"
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func open() {
        showWindow(nil)
        onVisibilityChanged(true)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onVisibilityChanged(false)
    }
}
