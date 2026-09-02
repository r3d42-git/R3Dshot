import AppKit
import CoreGraphics
import OSLog
import ScreenCaptureKit

enum CaptureError: LocalizedError, Equatable {
    case screenRecordingPermissionRequired
    case noCapturableWindow
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionRequired:
            "R3Dshot benötigt Zugriff auf Bildschirmaufnahme. Erlaube R3Dshot in Systemeinstellungen > Datenschutz & Sicherheit > Bildschirmaufnahme und versuche es anschließend erneut."
        case .noCapturableWindow:
            "Es ist derzeit kein aufnehmbares Fenster verfügbar."
        case .captureFailed:
            "R3Dshot konnte den Screenshot nicht erstellen. Bitte versuche es erneut."
        }
    }
}

/// Coordinates the user-facing capture flow. UI state is main-actor isolated;
/// ScreenCaptureKit is invoked only after the selection panels leave the window
/// server, so direct rect captures cannot include their own overlay.
@MainActor
final class CaptureCoordinator {
    var onCapture: ((CapturedScreenshot) -> Void)?
    var onError: ((CaptureError) -> Void)?
    var onCancellation: (() -> Void)?

    var includesWindowShadow = true
    /// The direct macOS 15.2 rectangle API has no cursor configuration. This
    /// preference currently applies to independent-window capture, which does.
    var includesMouseCursor = false

    private let permissionService: ScreenRecordingPermissionService
    private let overlayController = SelectionOverlayController()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "org.r3d.r3dshot",
        category: "Capture"
    )
    private var isCaptureInFlight = false

    init(permissionService: ScreenRecordingPermissionService? = nil) {
        self.permissionService = permissionService ?? ScreenRecordingPermissionService()
    }

    func captureArea() {
        beginUserInitiatedCapture { [weak self] in
            self?.overlayController.beginAreaSelection(
                onSelection: { [weak self] rect in
                    self?.captureRectangle(rect, source: .area(screenRectInPoints: rect))
                },
                onCancel: { [weak self] in
                    self?.cancelCapture()
                }
            )
        }
    }

    func captureWindow() {
        beginUserInitiatedCapture { [weak self] in
            self?.beginWindowSelection()
        }
    }

    private func beginWindowSelection() {
        Task { [weak self] in
            guard let self else { return }

            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    true,
                    onScreenWindowsOnly: true
                )
                let ownProcessID = ProcessInfo.processInfo.processIdentifier
                let windows = content.windows.filter {
                    $0.isOnScreen
                        && $0.windowLayer == 0
                        && $0.frame.width >= 32
                        && $0.frame.height >= 32
                        && $0.owningApplication?.processID != ownProcessID
                }

                guard !windows.isEmpty else {
                    self.complete(with: .failure(.noCapturableWindow))
                    return
                }

                self.overlayController.beginWindowSelection(
                    windows: self.windowsInFrontToBack(windows),
                    onSelection: { [weak self] window in
                        self?.capture(window: window)
                    },
                    onCancel: { [weak self] in
                        self?.cancelCapture()
                    }
                )
            } catch is CancellationError {
                self.cancelCapture()
            } catch {
                self.logger.error("Could not enumerate shareable windows")
                self.complete(with: .failure(.captureFailed))
            }
        }
    }

    func captureDisplay() {
        beginUserInitiatedCapture { [weak self] in
            self?.beginDisplaySelection()
        }
    }

    private func beginDisplaySelection() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            complete(with: .failure(.captureFailed))
            return
        }

        if screens.count == 1, let screen = screens.first {
            captureDisplay(screen)
            return
        }

        overlayController.beginDisplaySelection(
            onSelection: { [weak self] screen in
                self?.captureDisplay(screen)
            },
            onCancel: { [weak self] in
                self?.cancelCapture()
            }
        )
    }

    private func beginUserInitiatedCapture(then startCapture: @escaping @MainActor () -> Void) {
        guard !isCaptureInFlight else {
            logger.debug("Ignoring a capture command while another capture is active")
            return
        }

        isCaptureInFlight = true
        Task { [weak self] in
            guard let self else { return }

            guard await permissionService.requestAccessForUserInitiatedCapture() == .authorized else {
                complete(with: .failure(.screenRecordingPermissionRequired))
                return
            }

            startCapture()
        }
    }

    private func captureRectangle(_ rect: CGRect, source: CaptureSource) {
        guard !rect.isEmpty else {
            complete(with: .failure(.captureFailed))
            return
        }

        overlayController.dismiss()
        Task { [weak self] in
            guard let self else { return }
            do {
                await self.waitForOverlayRemoval()
                let image = try await self.captureAreaImage(in: rect)
                self.complete(with: .success(CapturedScreenshot(
                    id: UUID(),
                    image: image,
                    capturedAt: Date(),
                    source: source
                )))
            } catch is CancellationError {
                self.cancelCapture()
            } catch {
                self.logger.error("Direct rectangle capture failed")
                self.complete(with: .failure(.captureFailed))
            }
        }
    }

    private func captureDisplay(_ screen: NSScreen) {
        let rect = screen.frame
        overlayController.dismiss()

        Task { [weak self] in
            guard let self else { return }
            do {
                await self.waitForOverlayRemoval()
                let content = try await SCShareableContent.excludingDesktopWindows(
                    true,
                    onScreenWindowsOnly: true
                )
                let image = try await self.captureDisplayImage(screen, from: content)
                self.complete(with: .success(CapturedScreenshot(
                    id: UUID(),
                    image: image,
                    capturedAt: Date(),
                    source: .display(screenRectInPoints: rect)
                )))
            } catch is CancellationError {
                self.cancelCapture()
            } catch {
                self.logger.error("Display capture failed")
                self.complete(with: .failure(.captureFailed))
            }
        }
    }

    private func capture(window: SCWindow) {
        let includesShadow = includesWindowShadow
        overlayController.dismiss()

        Task { [weak self] in
            guard let self else { return }
            do {
                await self.waitForOverlayRemoval()
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let configuration = SCStreamConfiguration()
                let scale = NSScreen.screens.first(where: {
                    $0.frame.intersects(window.frame)
                })?.backingScaleFactor ?? 1
                configuration.width = Int((window.frame.width * scale).rounded(.up))
                configuration.height = Int((window.frame.height * scale).rounded(.up))
                configuration.showsCursor = includesMouseCursor
                configuration.ignoreShadowsSingleWindow = !includesShadow
                configuration.captureResolution = .best

                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )
                self.complete(with: .success(CapturedScreenshot(
                    id: UUID(),
                    image: image,
                    capturedAt: Date(),
                    source: .window(
                        windowID: window.windowID,
                        includesShadow: includesShadow
                    )
                )))
            } catch is CancellationError {
                self.cancelCapture()
            } catch {
                self.logger.error("Window capture failed")
                self.complete(with: .failure(.captureFailed))
            }
        }
    }

    /// `captureImage(in:)` is display-agnostic, but it has no configuration
    /// and can sample a compositor frame from before an overlay disappears.
    /// For one-display regions, take a fresh display frame and crop it in pixel
    /// coordinates instead. This preserves the current frontmost composition.
    private func captureAreaImage(in rect: CGRect) async throws -> CGImage {
        let intersectingScreens = NSScreen.screens.filter {
            !$0.frame.intersection(rect).isNull && !$0.frame.intersection(rect).isEmpty
        }

        guard let screen = intersectingScreens.only else {
            // The direct API remains the safe fallback for a selection spanning
            // differently scaled displays. It keeps the existing multi-display
            // behavior while the single-display path avoids stale frames.
            logger.notice("Using cross-display rectangle fallback")
            return try await SCScreenshotManager.captureImage(in: rect)
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
        let displayImage = try await captureDisplayImage(screen, from: content)
        return try crop(displayImage, to: rect, on: screen)
    }

    private func captureDisplayImage(
        _ screen: NSScreen,
        from content: SCShareableContent
    ) async throws -> CGImage {
        guard let displayID = displayID(for: screen),
              let display = content.displays.first(where: { $0.displayID == displayID })
        else {
            throw CaptureError.captureFailed
        }

        let scale = screen.backingScaleFactor
        let configuration = SCStreamConfiguration()
        configuration.width = Int((screen.frame.width * scale).rounded(.up))
        configuration.height = Int((screen.frame.height * scale).rounded(.up))
        configuration.showsCursor = includesMouseCursor
        configuration.captureResolution = .best

        let filter = SCContentFilter(display: display, excludingWindows: [])
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    private func crop(_ image: CGImage, to rect: CGRect, on screen: NSScreen) throws -> CGImage {
        let intersection = rect.intersection(screen.frame)
        guard !intersection.isNull, !intersection.isEmpty else {
            throw CaptureError.captureFailed
        }

        let pixelsPerPointX = CGFloat(image.width) / screen.frame.width
        let pixelsPerPointY = CGFloat(image.height) / screen.frame.height
        let localX = intersection.minX - screen.frame.minX
        let localTop = screen.frame.maxY - intersection.maxY
        let cropRect = CGRect(
            x: (localX * pixelsPerPointX).rounded(.down),
            y: (localTop * pixelsPerPointY).rounded(.down),
            width: (intersection.width * pixelsPerPointX).rounded(.up),
            height: (intersection.height * pixelsPerPointY).rounded(.up)
        ).intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard let croppedImage = image.cropping(to: cropRect.integral), !cropRect.isEmpty else {
            throw CaptureError.captureFailed
        }

        return croppedImage
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func windowsInFrontToBack(_ windows: [SCWindow]) -> [SCWindow] {
        let windowsByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.windowID, $0) })
        guard let windowInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return windows
        }

        var seenWindowIDs = Set<CGWindowID>()
        let orderedWindows = windowInfo.compactMap { info -> SCWindow? in
            guard let number = info[kCGWindowNumber as String] as? NSNumber,
                  let window = windowsByID[CGWindowID(number.uint32Value)]
            else {
                return nil
            }
            seenWindowIDs.insert(window.windowID)
            return window
        }

        return orderedWindows + windows.filter { !seenWindowIDs.contains($0.windowID) }
    }

    private func waitForOverlayRemoval() async {
        // Closing the panels removes their WindowServer surfaces. A short
        // compositor turn prevents capture of the outgoing dimming overlay or
        // a stale frame beneath it.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    private func complete(with result: Result<CapturedScreenshot, CaptureError>) {
        isCaptureInFlight = false

        switch result {
        case let .success(screenshot):
            logger.info("Capture completed")
            onCapture?(screenshot)
        case let .failure(error):
            onError?(error)
        }
    }

    private func cancelCapture() {
        guard isCaptureInFlight else { return }
        isCaptureInFlight = false
        logger.debug("Capture selection cancelled")
        onCancellation?()
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? first : nil
    }
}
