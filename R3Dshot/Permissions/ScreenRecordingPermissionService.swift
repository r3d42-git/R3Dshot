import CoreGraphics
import Foundation
import OSLog
import ScreenCaptureKit

/// The actionable states of macOS's Screen Recording TCC permission.
///
/// CoreGraphics cannot reliably distinguish a declined request from the
/// "restart the app" state after a first-time approval. Both need the same UI:
/// direct the person to System Settings and allow a retry afterwards.
enum ScreenRecordingPermissionState: Equatable {
    case authorized
    case needsUserAction
}

/// Keeps the CoreGraphics TCC calls in one small, user-initiated boundary.
@MainActor
final class ScreenRecordingPermissionService {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "org.r3d.r3dshot",
        category: "ScreenRecordingPermission"
    )

    func preflight() -> ScreenRecordingPermissionState {
        CGPreflightScreenCaptureAccess() ? .authorized : .needsUserAction
    }

    /// Requests access only in direct response to a capture command. The System
    /// Settings prompt is owned by macOS; this method never tries to infer or
    /// persist a permission decision itself.
    func requestAccessForUserInitiatedCapture() async -> ScreenRecordingPermissionState {
        guard preflight() != .authorized else {
            return .authorized
        }

        logger.notice("Requesting Screen Recording access after a capture command")
        _ = CGRequestScreenCaptureAccess()

        guard preflight() != .authorized else {
            return .authorized
        }

        // On recent macOS releases the CoreGraphics preflight can retain a
        // negative result for an already-approved app instance. Ask the API
        // used by the capture implementation before showing a false denial.
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )
            logger.info("ScreenCaptureKit confirmed Screen Recording access")
            return .authorized
        } catch {
            logger.notice("ScreenCaptureKit did not confirm Screen Recording access")
            return .needsUserAction
        }
    }
}
