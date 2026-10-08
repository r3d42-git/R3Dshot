import AppKit
import Darwin

/// Native panel/lifecycle regression harness. No screen capture or installed app
/// interaction. Compile the production controller directly into this executable.
@main
struct SelectionOverlaySmoke {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                try await runChecks()
                print("Selection overlay lifecycle smoke test passed")
                exit(0)
            } catch {
                fputs("Selection overlay test failed: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }

    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    @MainActor
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw Failure(description: message) }
    }

    @MainActor
    static func pause(_ milliseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
    }

    @MainActor
    static func panels() -> [NSPanel] {
        NSApp.windows.compactMap { $0 as? NSPanel }.filter {
            $0.isVisible && $0.title == "R3Dshot – Aufnahme auswählen"
        }
    }

    @MainActor
    static func runChecks() async throws {
        try check(!NSScreen.screens.isEmpty, "A GUI session with a screen is required")
        let controller = SelectionOverlayController()
        defer { controller.dismiss() }
        var cancellations = 0
        var stage = "startup"
        func diagnose(_ label: String) {
            let states = NSApp.windows.compactMap { $0 as? NSPanel }.map {
                "\($0.windowNumber):visible=\($0.isVisible),key=\($0.isKeyWindow),selectionResponder=\($0.firstResponder === $0.contentView)"
            }.joined(separator: "; ")
            print("[\(stage)] \(label): selecting=\(controller.isSelecting), cancellations=\(cancellations), appActive=\(NSApp.isActive); \(states)")
        }
        func begin() {
            controller.beginAreaSelection(onSelection: { _ in }, onCancel: {
                cancellations += 1
                diagnose("cancelled")
            })
        }

        begin()
        let shownPanels = panels()
        try check(shownPanels.count == NSScreen.screens.count, "One visible panel per display")
        for panel in shownPanels {
            try check(panel.styleMask.contains(.nonactivatingPanel), "Panel must be nonactivating")
            try check(!panel.hidesOnDeactivate, "Inactive app must keep selection visible")
            try check(panel.canBecomeKey && !panel.canBecomeMain, "Panel key/main policy")
            try check(NSScreen.screens.contains { $0.frame == panel.frame }, "Exact screen frame")
        }
        try await pause(350)
        try check(controller.isSelecting, "First selection must acquire focus without Settings")
        try check(shownPanels.contains { $0.isKeyWindow && $0.firstResponder === $0.contentView },
                  "Selection view owns keyboard focus")

        let other = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
                            styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { other.close() }

        // Exercise WindowServer/AppKit key-window bookkeeping rather than
        // calling resignKey directly (a notification hook, not a focus action).
        // A short native handoff must survive the 150 ms debounce.
        let keyPanel = shownPanels.first { $0.isKeyWindow }!
        stage = "transient focus loss"
        other.makeKeyAndOrderFront(nil)
        diagnose("temporary panel took focus")
        try check(other.isKeyWindow && !keyPanel.isKeyWindow, "Temporary panel must actually take focus")
        try await pause(30)
        keyPanel.makeKeyAndOrderFront(nil)
        diagnose("selection regained focus")
        try check(keyPanel.isKeyWindow && keyPanel.firstResponder === keyPanel.contentView,
                  "Native handoff must restore selection keyboard focus")
        other.orderOut(nil)
        try await pause(200)
        diagnose("after settling")
        try check(controller.isSelecting && cancellations == 0, "Transient focus loss must survive")
        try check(keyPanel.isKeyWindow && keyPanel.firstResponder === keyPanel.contentView,
                  "Selection must retain keyboard focus after handoff")

        // An ordinary native window taking focus is a genuine interruption.
        stage = "genuine focus loss"
        other.makeKeyAndOrderFront(nil)
        diagnose("other panel took focus")
        try check(other.isKeyWindow && !keyPanel.isKeyWindow, "Other panel must actually take focus")
        try await pause(220)
        try check(!controller.isSelecting && cancellations == 1, "Genuine focus loss must cancel once")
        other.close()
        try check(panels().isEmpty, "Cancellation closes all panels")

        // A pending focus-loss check must not cancel a replacement selection.
        stage = "replacement with pending focus loss"
        begin()
        try await pause(350)
        other.makeKeyAndOrderFront(nil)
        begin()
        other.orderOut(nil)
        try await pause(350)
        try check(controller.isSelecting && cancellations == 1,
                  "Retired focus-loss check cannot cancel replacement")
        controller.dismiss()

        // Startup failure is bounded even when no panel can retain focus.
        stage = "failed startup"
        begin()
        try await pause(50)
        panels().forEach { $0.orderOut(nil) }
        try await pause(350)
        try check(!controller.isSelecting && cancellations == 2, "Failed focus acquisition releases selection")

        // Old panel events and queued workspace work must not touch the new ID.
        stage = "retired callbacks"
        begin()
        let retiredView = panels().first!.contentView!
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        begin()
        retiredView.cancelOperation(nil)
        try await pause(350)
        try check(controller.isSelecting && cancellations == 2, "Retired callbacks cannot cancel replacement")

        // All interruption paths cancel the active selection and allow recovery.
        let interruptions: [(NotificationCenter, Notification.Name)] = [
            (.default, NSApplication.didChangeScreenParametersNotification),
            (.default, NSApplication.didHideNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.activeSpaceDidChangeNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.willSleepNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.screensDidSleepNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.sessionDidResignActiveNotification)
        ]
        for (center, name) in interruptions {
            stage = "interruption \(name.rawValue)"
            let countBefore = cancellations
            center.post(name: name, object: nil)
            try await pause(30)
            try check(!controller.isSelecting && cancellations == countBefore + 1,
                      "Active interruption must cancel: \(name.rawValue)")
            begin()
        }
        controller.dismiss()
        let countBefore = cancellations
        try await pause(350)
        try check(!controller.isSelecting && cancellations == countBefore, "Dismissed startup work stays inert")
    }
}
