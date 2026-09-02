import CoreGraphics
import Foundation

/// Describes the logical source of a capture. All rectangles use global macOS
/// screen coordinates measured in points; the resulting image remains in pixels.
enum CaptureSource: Equatable {
    case area(screenRectInPoints: CGRect)
    case window(windowID: CGWindowID, includesShadow: Bool)
    case display(screenRectInPoints: CGRect)
}

/// Immutable image data and metadata passed from capture to the quick-action flow.
///
/// No consumer should mutate `image`. The later document model adds crop and
/// annotations separately, preserving these original pixels as the source image.
struct CapturedScreenshot: Identifiable {
    let id: UUID
    let image: CGImage
    let capturedAt: Date
    let source: CaptureSource

    var pixelSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }
}
