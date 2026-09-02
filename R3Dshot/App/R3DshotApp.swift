import SwiftUI

@main
struct R3DshotApp: App {
    @NSApplicationDelegateAdaptor(R3DshotAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                preferences: appDelegate.preferences,
                shortcuts: appDelegate.shortcuts,
                onShortcutRecordingChanged: appDelegate.setShortcutRecordingActive
            )
        }
    }
}
