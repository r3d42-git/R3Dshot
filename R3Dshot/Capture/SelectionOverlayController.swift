import AppKit
import OSLog
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
    private var selectionID: UUID?
    private var startupFocusTask: Task<Void, Never>?
    private var focusLossTask: Task<Void, Never>?
    private var isStarting = false
    private var interruptionObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var mode: Mode?
    private var areaCompletion: ((CGRect) -> Void)?
    private var displayCompletion: ((NSScreen) -> Void)?
    private var windowCompletion: ((SCWindow) -> Void)?
    private var cancellationCompletion: (() -> Void)?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "org.r3d.r3dshot",
        category: "Selection"
    )

    var isSelecting: Bool { mode != nil }

    func beginAreaSelection(
        onSelection: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        dismiss()
        areaCompletion = onSelection
        start(mode: .area, onCancel: onCancel)
    }

    func beginDisplaySelection(
        onSelection: @escaping (NSScreen) -> Void,
        onCancel: @escaping () -> Void
    ) {
        dismiss()
        displayCompletion = onSelection
        start(mode: .display, onCancel: onCancel)
    }

    func beginWindowSelection(
        windows: [SCWindow],
        onSelection: @escaping (SCWindow) -> Void,
        onCancel: @escaping () -> Void
    ) {
        dismiss()
        windowCompletion = onSelection
        start(mode: .window(windows), onCancel: onCancel)
    }

    /// Removes every overlay from the window server before a direct rect
    /// capture. The caller then yields once to let the compositor present that
    /// removal before invoking `SCScreenshotManager`.
    func dismiss() {
        // Invalidate first: closing a panel can synchronously resign key status.
        selectionID = nil
        startupFocusTask?.cancel()
        startupFocusTask = nil
        focusLossTask?.cancel()
        focusLossTask = nil
        isStarting = false
        interruptionObservers.forEach { $0.0.removeObserver($0.1) }
        interruptionObservers.removeAll()
        panels.forEach { $0.close() }
        panels.removeAll()
        mode = nil
        areaCompletion = nil
        displayCompletion = nil
        windowCompletion = nil
        cancellationCompletion = nil
    }

    private func start(mode: Mode, onCancel: @escaping () -> Void) {
        let id = UUID()
        selectionID = id
        isStarting = true
        self.mode = mode
        cancellationCompletion = onCancel

        panels = NSScreen.screens.map { screen in
            SelectionOverlayPanel(screen: screen, owner: self, selectionID: id)
        }

        guard !panels.isEmpty else {
            cancel()
            return
        }
        observeInterruptions(for: id)
        panels.forEach { $0.orderFrontRegardless() }
        pointerMoved(to: NSEvent.mouseLocation)
        refreshCursorOwnership()
        logger.info("Selection overlays shown: \(self.panels.count, privacy: .public) panels")

        // Menu tracking can release focus after the command returns. Allow one
        // bounded retry, then either retain a usable selection or cancel it.
        // Never keep reclaiming focus from the user's other windows.
        startupFocusTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.selectionID == id, !Task.isCancelled else { return }
            if !self.hasSelectionFocus { self.refreshCursorOwnership() }
            do { try await Task.sleep(nanoseconds: 250_000_000) }
            catch { return }
            guard self.selectionID == id else { return }
            self.isStarting = false
            self.startupFocusTask = nil
            if !self.hasSelectionFocus {
                self.logger.notice("Selection could not retain keyboard focus")
                self.cancel()
            }
        }
    }

    private var hasSelectionFocus: Bool {
        panels.contains { $0.isVisible && $0.isKeyWindow && $0.firstResponder === $0.selectionView }
    }

    fileprivate func ownsSelection(_ id: UUID) -> Bool { selectionID == id }

    fileprivate func panelFocusChanged(selectionID id: UUID, gainedFocus: Bool) {
        guard selectionID == id else { return }
        if gainedFocus {
            focusLossTask?.cancel()
            focusLossTask = nil
            return
        }
        guard !isStarting else { return }
        focusLossTask?.cancel()
        // Key status may briefly be absent while crossing between displays.
        // Check the whole selection after that transfer has settled.
        focusLossTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 150_000_000) }
            catch { return }
            guard let self, self.selectionID == id else { return }
            self.focusLossTask = nil
            if !self.hasSelectionFocus {
                self.logger.info("Selection lost keyboard focus")
                self.cancel()
            }
        }
    }

    private func observeInterruptions(for id: UUID) {
        let notifications: [(NotificationCenter, Notification.Name)] = [
            (.default, NSApplication.didChangeScreenParametersNotification),
            (.default, NSApplication.didHideNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.activeSpaceDidChangeNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.willSleepNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.screensDidSleepNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.sessionDidResignActiveNotification)
        ]
        for (center, name) in notifications {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.selectionID == id else { return }
                    self.logger.info("Selection interrupted by workspace or display change")
                    self.cancel()
                }
            }
            interruptionObservers.append((center, observer))
        }
    }

    private func refreshCursorOwnership() {
        guard mode != nil else { return }

        let mouseLocation = NSEvent.mouseLocation
        let panel = panels.first { $0.frame.contains(mouseLocation) } ?? panels.first
        panel?.makeKeyAndOrderFront(nil)
        if let panel {
            panel.makeFirstResponder(panel.selectionView)
            logger.debug("Selection focus refreshed: visible=\(panel.isVisible, privacy: .public), key=\(panel.isKeyWindow, privacy: .public)")
        }
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
        guard isSelecting else { return }
        logger.info("Selection cancelled")
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
    private weak var owner: SelectionOverlayController?
    private let selectionID: UUID

    init(screen: NSScreen, owner: SelectionOverlayController, selectionID: UUID) {
        self.owner = owner
        self.selectionID = selectionID
        selectionView = SelectionOverlayView(screen: screen, owner: owner, selectionID: selectionID)

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        title = "R3Dshot – Aufnahme auswählen"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        becomesKeyOnlyIfNeeded = false
        // Selection must stay visible while the menu-bar app is inactive.
        // A nonactivating panel takes keyboard focus without activating the
        // accessory app or disturbing the app being captured.
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isRestorable = false
        selectionView.autoresizingMask = [.width, .height]
        contentView = selectionView
        setFrame(screen.frame, display: false)
    }

    override func becomeKey() {
        super.becomeKey()
        owner?.panelFocusChanged(selectionID: selectionID, gainedFocus: true)
    }

    override func resignKey() {
        super.resignKey()
        owner?.panelFocusChanged(selectionID: selectionID, gainedFocus: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Overlays cover the entire display, including its menu bar and Dock;
    // AppKit's ordinary visible-frame constraint is inappropriate here.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

private final class SelectionOverlayView: NSView {
    private weak var selectionOwner: SelectionOverlayController?
    private let selectionID: UUID
    // Retired panels can still have queued events. They must not select,
    // cancel, or acquire focus for a replacement selection.
    private var owner: SelectionOverlayController? {
        guard selectionOwner?.ownsSelection(selectionID) == true else { return nil }
        return selectionOwner
    }
    private let screen: NSScreen
    private var areaStart: CGPoint?
    private var areaRect: CGRect?
    private var isPointerInside = false
    private var pointerLocation: CGPoint?
    private var trackingArea: NSTrackingArea?

    init(screen: NSScreen, owner: SelectionOverlayController, selectionID: UUID) {
        self.screen = screen
        self.selectionOwner = owner
        self.selectionID = selectionID
        super.init(frame: CGRect(origin: .zero, size: screen.frame.size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func cancelOperation(_ sender: Any?) {
        owner?.cancel()
    }

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
        guard owner != nil else { return }
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
        guard owner != nil else { return }
        guard let screenPoint = globalScreenPoint(for: event) else { return }
        owner?.pointerMoved(to: screenPoint)
        NSCursor.crosshair.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        guard owner != nil else { return }
        NSCursor.crosshair.set()
    }

    override func mouseDown(with event: NSEvent) {
        guard owner != nil else { return }
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
        guard owner != nil else { return }
        guard let screenPoint = globalScreenPoint(for: event) else { return }
        owner?.updateArea(to: screenPoint)
        NSCursor.crosshair.set()
    }

    override func mouseUp(with event: NSEvent) {
        guard owner != nil else { return }
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
