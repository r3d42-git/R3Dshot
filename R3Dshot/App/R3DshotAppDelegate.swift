import AppKit

@MainActor
final class R3DshotAppDelegate: NSObject, NSApplicationDelegate {
    let preferences = PreferencesStore()
    let shortcuts = ShortcutStore()

    private let pendingCaptures = PendingCaptureStore()
    private let fileStore = ScreenshotFileStore()
    private lazy var editorController = EditorWindowController(
        fileStore: fileStore,
        preferences: preferences,
        onEditorsChanged: { [weak self] in
            self?.refreshEditorAvailability()
        }
    )

    private var captureCoordinator: CaptureCoordinator?
    private var quickActionController: QuickActionPanelController?
    private var menuBarController: MenuBarController?
    private var hotKeyManager: GlobalHotKeyManager?
    private var settingsWindowController: SettingsWindowController?
    private var isCompletingTermination = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let captureCoordinator = CaptureCoordinator()
        captureCoordinator.onCapture = { [weak self] screenshot in
            self?.handleCapturedScreenshot(screenshot)
        }
        captureCoordinator.onError = { [weak self] error in
            self?.presentCaptureError(error)
        }

        let quickActionController = QuickActionPanelController(
            fileStore: fileStore,
            captureStore: pendingCaptures,
            preferences: preferences,
            openEditor: { [weak self] capture in
                self?.openEditor(for: capture)
            },
            onCaptureRemoved: { [weak self] in
                self?.refreshEditorAvailability()
            }
        )

        let settingsWindowController = SettingsWindowController(
            preferences: preferences,
            shortcuts: shortcuts,
            onShortcutRecordingChanged: { [weak self] isRecording in
                self?.setShortcutRecordingActive(isRecording)
            },
            onVisibilityChanged: { [weak self] _ in
                self?.refreshApplicationActivationPolicy()
            }
        )

        let menuBarController = MenuBarController(shortcutStore: shortcuts)
        menuBarController.onCaptureRequested = { [weak self] action in
            self?.requestCapture(action)
        }
        menuBarController.onEditorRequested = { [weak self] in
            self?.openLatestEditor()
        }
        menuBarController.onSettingsRequested = { [weak self] in
            self?.openSettings()
        }
        menuBarController.onAboutRequested = { [weak self] in
            self?.openAboutPanel()
        }
        menuBarController.onQuitRequested = { [weak self] in
            self?.requestTermination()
        }

        let hotKeyManager = GlobalHotKeyManager(shortcutStore: shortcuts)
        hotKeyManager.onCaptureAction = { [weak self] action in
            self?.requestCapture(action)
        }
        hotKeyManager.onRegistrationStateChange = { action, state in
            if case .failed = state {
                AppLogger.shortcuts.error("Could not register shortcut for \(action.rawValue, privacy: .public)")
            }
        }
        hotKeyManager.start()

        self.captureCoordinator = captureCoordinator
        self.quickActionController = quickActionController
        self.menuBarController = menuBarController
        self.hotKeyManager = hotKeyManager
        self.settingsWindowController = settingsWindowController

        AppLogger.application.info("R3Dshot menu bar app started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.invalidate()
        menuBarController?.invalidate()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isCompletingTermination else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "R3Dshot beenden?"
        alert.informativeText = "R3Dshot kann weiter im Hintergrund in der Menüleiste bereitstehen."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "In Menüleiste behalten")
        alert.addButton(withTitle: "R3Dshot beenden")
        alert.addButton(withTitle: "Abbrechen")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            guard editorController.closeAllEditors() else {
                refreshApplicationActivationPolicy()
                return .terminateCancel
            }
            settingsWindowController?.close()
            refreshApplicationActivationPolicy()
            return .terminateCancel
        case .alertSecondButtonReturn:
            guard editorController.closeAllEditors() else {
                refreshApplicationActivationPolicy()
                return .terminateCancel
            }
            settingsWindowController?.close()
            isCompletingTermination = true
            return .terminateNow
        default:
            return .terminateCancel
        }
    }

    func setShortcutRecordingActive(_ isActive: Bool) {
        hotKeyManager?.setShortcutRecordingActive(isActive)
    }

    private func requestCapture(_ action: CaptureAction) {
        guard let captureCoordinator else {
            return
        }

        captureCoordinator.includesWindowShadow = preferences.includeWindowShadow
        captureCoordinator.includesMouseCursor = preferences.includeMouseCursor

        switch action {
        case .area:
            captureCoordinator.captureArea()
        case .window:
            captureCoordinator.captureWindow()
        case .display:
            captureCoordinator.captureDisplay()
        }
    }

    private func handleCapturedScreenshot(_ screenshot: CapturedScreenshot) {
        let capture = pendingCaptures.insert(screenshot)
        menuBarController?.isEditorAvailable = true

        if preferences.showsQuickActionPanel {
            quickActionController?.show(capture)
            return
        }

        do {
            _ = try fileStore.saveDefault(capture, preferences: preferences)
            pendingCaptures.remove(capture)
            refreshEditorAvailability()
        } catch {
            present(error)
        }
    }

    private func openLatestEditor() {
        guard let capture = pendingCaptures.captures.first else {
            refreshApplicationActivationPolicy()
            editorController.focusMostRecentEditor()
            return
        }
        refreshApplicationActivationPolicy()
        openEditor(for: capture)
    }

    private func openEditor(for capture: PendingCapture) {
        editorController.open(capture)
        pendingCaptures.remove(capture)
        refreshEditorAvailability()
    }

    private func openSettings() {
        refreshApplicationActivationPolicy()
        settingsWindowController?.open()
    }

    private func openAboutPanel() {
        refreshApplicationActivationPolicy()
        NSApp.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "R3Dshot",
                .applicationVersion: "0.1.0",
                .version: "Phase 3"
            ]
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentCaptureError(_ error: CaptureError) {
        let alert = NSAlert()
        alert.messageText = "Aufnahme nicht möglich"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning

        if error == .screenRecordingPermissionRequired {
            alert.addButton(withTitle: "Systemeinstellungen öffnen")
            alert.addButton(withTitle: "Abbrechen")

            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func present(_ error: Error) {
        NSAlert(error: error).runModal()
    }

    private func refreshEditorAvailability() {
        menuBarController?.isEditorAvailable = !pendingCaptures.captures.isEmpty
            || editorController.hasOpenEditors
        refreshApplicationActivationPolicy()
    }

    private func requestTermination() {
        NSApp.terminate(nil)
    }

    /// Editor windows are the sole reason R3Dshot becomes a regular Dock app.
    /// Settings and auxiliary panels remain usable while the process stays an
    /// accessory menu-bar application.
    private func refreshApplicationActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = editorController.hasOpenEditors
            ? .regular
            : .accessory
        guard NSApp.activationPolicy() != policy else {
            return
        }
        NSApp.setActivationPolicy(policy)
    }
}
