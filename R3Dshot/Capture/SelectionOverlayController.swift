import AppKit
import ScreenCaptureKit

/// Displays short-lived selection panels above every screen.
///
/// The AppKit boundary is intentionally confined to these panels: the capture
/// coordinator receives only a global rect or a selected `SCWindow`.
@MainActor
final class SelectionOverlayController {
    fileprivate enum Mode {
        case area
        case display
        case window([SCWindow])
    }

    private var panels: [SelectionOverlayPanel] = []
    private var mode: Mode?
    private var areaCompletion: ((CGRect) -> Void)?
    private var displayCompletion: ((NSScreen) -> Void)?
    private var windowCompletion: ((SCWindow) -> Void)?
    private var cancellationCompletion: (() -> Void)?
    private var previouslyActiveApplication: NSRunningApplication?
    private var activatedApplicationForSelection = false

    func beginAreaSelection(
        onSelection: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        start(mode: .area, onCancel: onCancel)
        areaCompletion = onSelection
    }

    func beginDisplaySelection(
        onSelection: @escaping (NSScreen) -> Void,
        onCancel: @escaping () -> Void
    ) {
        start(mode: .display, onCancel: onCancel)
        displayCompletion = onSelection
    }

    func beginWindowSelection(
        windows: [SCWindow],
        onSelection: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void
    ) {
        start(mode: .window(windows), onCancel: onCancel)
        windowCompletion = onSelection
    }

    /// Removes every overlay from the window server before a direct rect
    /// capture. The caller then yields once to let the compositor present that
    /// removal before invoking `SCScreenshotManager`.
    func dismiss() {
        panels.forEach { $0.close() }
        panels.removeAll()
        mode = nil
        areaCompletion = nil
        displayCompletion = nil
        windowCompletion = nil
        cancellationCompletion = nil
        restorePreviousApplicationIfNeeded()
    }

    private func start(mode: Mode, onCancel: @escaping () -> Void) {
        dismiss()
        self.mode = mode
        cancellationCompletion = onCancel
        activateApplicationForSelectionIfNeeded()

        panels = NSScreen.screens.map { screen in
            SelectionOverlayPanel(screen: screen, owner: self)
        }

        panels.forEach { $0.orderFrontRegardless() }
        pointerMoved(to: NSEvent.mouseLocation)
        refreshCursorOwnership()

        // Application activation can complete one event-loop turn after the
        // request. Refresh the key panel and its native cursor rect once AppKit
        // has had a chance to finish the transition.
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.refreshCursorOwnership()
        }
    }

    private func activateApplicationForSelectionIfNeeded() {
        guard !NSApp.isActive else { return }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        if frontmostApplication?.processIdentifier != currentProcessIdentifier {
            previouslyActiveApplication = frontmostApplication
        }

        activatedApplicationForSelection = true
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restorePreviousApplicationIfNeeded() {
        guard activatedApplicationForSelection else { return }

        let applicationToRestore = previouslyActiveApplication
        previouslyActiveApplication = nil
        activatedApplicationForSelection = false

        if let applicationToRestore, !applicationToRestore.isTerminated {
            NSApp.yieldActivation(to: applicationToRestore)
            if !applicationToRestore.activate() {
                NSApp.deactivate()
            }
        } else {
            NSApp.deactivate()
        }
    }

    private func refreshCursorOwnership() {
        guard mode != nil else { return }

        let mouseLocation = NSEvent.mouseLocation
        let panel = panels.first { $0.frame.contains(mouseLocation) } ?? panels.first
        panel?.makeKeyAndOrderFront(nil)
        panel?.selectionView.activateCrosshairCursor()
    }

    fileprivate func beginArea(at screenPoint: CGPoint) {
        guard case .area? = mode else { return }
        panels.forEach { $0.selectionView.beginArea(at: screenPoint) }
    }

    fileprivate var activeMode: Mode? {
        mode
    }

    fileprivate func updateArea(to screenPoint: CGPoint) {
        guard case .area? = mode else { return }
        panels.forEach { $0.selectionView.updateArea(to: screenPoint) }
    }

    fileprivate func finishArea(at screenPoint: CGPoint) {
        guard case .area? = mode,
              let rect = panels.first?.selectionView.finishArea(at: screenPoint),
              rect.width >= 2,
              rect.height >= 2
        else {
            cancel()
            return
        }

        let completion = areaCompletion
        dismiss()
        completion?(rect)
    }

    fileprivate func selectDisplay(_ screen: NSScreen) {
        guard case .display? = mode else { return }
        let completion = displayCompletion
        dismiss()
        completion?(screen)
    }

    fileprivate func window(at screenPoint: CGPoint) -> SCWindow? {
        guard case let .window(windows)? = mode else { return nil }

        // CaptureCoordinator explicitly supplies front-to-back WindowServer
        // order. The first matching window is therefore the visible one.
        guard let screenCapturePoint = screenCapturePoint(from: screenPoint) else {
            return nil
        }
        return windows.first { $0.frame.contains(screenCapturePoint) }
    }

    fileprivate func pointerMoved(to screenPoint: CGPoint) {
        panels.forEach { $0.selectionView.updatePointer(to: screenPoint) }
    }

    fileprivate func selectWindow(at screenPoint: CGPoint) {
        guard let window = window(at: screenPoint) else { return }
        let completion = windowCompletion
        dismiss()
        completion?(window)
    }

    fileprivate func cancel() {
        let completion = cancellationCompletion
        dismiss()
        completion?()
    }

    /// AppKit's global screen coordinates grow upward; ScreenCaptureKit window
    /// frames use the WindowServer coordinate system, whose Y axis grows
    /// downward. Without this conversion, clicking an upper window selects a
    /// window at the vertically mirrored position.
    fileprivate func screenCapturePoint(from appKitPoint: CGPoint) -> CGPoint? {
        guard let top = NSScreen.screens.map(\.frame.maxY).max() else {
            return nil
        }
        return CGPoint(x: appKitPoint.x, y: top - appKitPoint.y)
    }

    fileprivate func appKitRect(from screenCaptureRect: CGRect) -> CGRect? {
        guard let top = NSScreen.screens.map(\.frame.maxY).max() else {
            return nil
        }
        return CGRect(
            x: screenCaptureRect.minX,
            y: top - screenCaptureRect.maxY,
            width: screenCaptureRect.width,
            height: screenCaptureRect.height
        )
    }
}

private final class SelectionOverlayPanel: NSPanel {
    let selectionView: SelectionOverlayView

    init(screen: NSScreen, owner: SelectionOverlayController) {
        selectionView = SelectionOverlayView(screen: screen, owner: owner)

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        becomesKeyOnlyIfNeeded = false
        contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class SelectionOverlayView: NSView {
    private weak var owner: SelectionOverlayController?
    private let screen: NSScreen
    private var areaStart: CGPoint?
    private var areaRect: CGRect?
    private var isPointerInside = false
    private var pointerLocation: CGPoint?
    private var trackingArea: NSTrackingArea?

    init(screen: NSScreen, owner: SelectionOverlayController) {
        self.screen = screen
        self.owner = owner
        super.init(frame: CGRect(origin: .zero, size: screen.frame.size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        window?.makeFirstResponder(self)
        window?.invalidateCursorRects(for: self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.24).setFill()
        bounds.fill()

        if let areaRect {
            drawAreaSelection(areaRect)
        } else if isPointerInside {
            switch owner?.activeMode {
            case .display:
                drawDisplayHighlight()
            case .window(_):
                drawWindowHighlight()
            case .area, .none:
                break
            }
        }

    }

    override func mouseEntered(with event: NSEvent) {
        window?.makeKey()
        activateCrosshairCursor()
        if let screenPoint = globalScreenPoint(for: event) {
            owner?.pointerMoved(to: screenPoint)
        }
        isPointerInside = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isPointerInside = false
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        guard let screenPoint = globalScreenPoint(for: event) else { return }
        owner?.pointerMoved(to: screenPoint)
        NSCursor.crosshair.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseDown(with event: NSEvent) {
        guard let screenPoint = globalScreenPoint(for: event) else { return }
        NSCursor.crosshair.set()

        switch owner?.activeMode {
        case .window(_):
            owner?.selectWindow(at: screenPoint)
        case .display:
            owner?.selectDisplay(screen)
        case .area:
            owner?.beginArea(at: screenPoint)
        case .none:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let screenPoint = globalScreenPoint(for: event) else { return }
        owner?.updateArea(to: screenPoint)
        NSCursor.crosshair.set()
    }

    override func mouseUp(with event: NSEvent) {
        guard let screenPoint = globalScreenPoint(for: event) else { return }
        owner?.finishArea(at: screenPoint)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            owner?.cancel()
            return
        }
        super.keyDown(with: event)
    }

    fileprivate func beginArea(at screenPoint: CGPoint) {
        areaStart = screenPoint
        areaRect = CGRect(origin: screenPoint, size: .zero)
        needsDisplay = true
    }

    fileprivate func updateArea(to screenPoint: CGPoint) {
        guard let areaStart else { return }
        areaRect = CGRect(
            x: min(areaStart.x, screenPoint.x),
            y: min(areaStart.y, screenPoint.y),
            width: abs(screenPoint.x - areaStart.x),
            height: abs(screenPoint.y - areaStart.y)
        )
        needsDisplay = true
    }

    fileprivate func finishArea(at screenPoint: CGPoint) -> CGRect? {
        updateArea(to: screenPoint)
        defer {
            areaStart = nil
            areaRect = nil
        }
        return areaRect?.standardized
    }

    fileprivate func updatePointer(to screenPoint: CGPoint) {
        pointerLocation = screenPoint
        needsDisplay = true
    }

    fileprivate func activateCrosshairCursor() {
        window?.invalidateCursorRects(for: self)
        NSCursor.crosshair.set()
    }

    private func globalScreenPoint(for event: NSEvent) -> CGPoint? {
        guard let window else { return nil }
        return window.convertPoint(toScreen: event.locationInWindow)
    }

    private func drawDisplayHighlight() {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        NSColor.controlAccentColor.withAlphaComponent(0.95).setStroke()
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        path.lineWidth = 3
        path.stroke()
    }

    private func drawWindowHighlight() {
        guard let pointerLocation,
              let selectedWindow = owner?.window(at: pointerLocation),
              let windowRect = owner?.appKitRect(from: selectedWindow.frame)
        else { return }

        let localRect = windowRect
            .intersection(screen.frame)
            .offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        guard !localRect.isNull, !localRect.isEmpty else { return }

        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        localRect.fill()
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(roundedRect: localRect.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        path.lineWidth = 3
        path.stroke()
    }

    private func drawAreaSelection(_ screenRect: CGRect) {
        let localRect = screenRect
            .intersection(screen.frame)
            .offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)

        guard !localRect.isNull, !localRect.isEmpty else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .copy
        NSColor.clear.setFill()
        localRect.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: localRect)
        path.lineWidth = 2
        path.stroke()

        // The same selection is rendered by every panel; show its dimensions
        // only on the screen where the drag began.
        guard let areaStart, screen.frame.contains(areaStart) else { return }

        let label = pixelSizeLabel(for: screenRect)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let labelSize = label.size(withAttributes: attributes)
        let labelRect = CGRect(
            x: localRect.minX + 8,
            y: max(localRect.minY - labelSize.height - 14, 8),
            width: labelSize.width + 12,
            height: labelSize.height + 8
        )

        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 5, yRadius: 5).fill()
        label.draw(at: CGPoint(x: labelRect.minX + 6, y: labelRect.minY + 4), withAttributes: attributes)
    }

    private func pixelSizeLabel(for screenRect: CGRect) -> String {
        let scale = screen.backingScaleFactor
        let width = Int((screenRect.width * scale).rounded())
        let height = Int((screenRect.height * scale).rounded())
        return "\(width) × \(height) px"
    }
}
