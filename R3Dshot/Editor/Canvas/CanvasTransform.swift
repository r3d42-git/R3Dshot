import CoreGraphics

/// Zoom is measured in physical display pixels per source image pixel.
/// AppKit/SwiftUI layout uses points, so Retina screens need a conversion.
enum CanvasZoom {
    static func fittedZoom(imageSize: CGSize, viewportSize: CGSize, displayScale: CGFloat) -> CGFloat {
        let availableWidth = max(1, viewportSize.width - 64)
        let availableHeight = max(1, viewportSize.height - 64)
        let scale = min(availableWidth / max(1, imageSize.width), availableHeight / max(1, imageSize.height))
        // Small screenshots keep their original pixels rather than being
        // enlarged and softened just to fill a large editor window.
        return max(0.01, min(1, scale * max(1, displayScale)))
    }

    static func viewScale(zoom: CGFloat, displayScale: CGFloat) -> CGFloat {
        zoom / max(1, displayScale)
    }
}

struct CanvasTransform {
    let canvasSize: PixelSize
    let scale: CGFloat
    let canvasOrigin: CGPoint

    init(canvasSize: PixelSize, scale: CGFloat, canvasOrigin: CGPoint = .zero) {
        self.canvasSize = canvasSize
        self.scale = scale
        self.canvasOrigin = canvasOrigin
    }

    func canvasPoint(from viewPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: canvasOrigin.x + min(max(0, viewPoint.x / scale), canvasSize.cgSize.width),
            y: canvasOrigin.y + min(max(0, viewPoint.y / scale), canvasSize.cgSize.height)
        )
    }

    func viewRect(from canvasRect: CanvasRect) -> CGRect {
        CGRect(
            x: (canvasRect.x - canvasOrigin.x) * scale,
            y: (canvasRect.y - canvasOrigin.y) * scale,
            width: canvasRect.width * scale,
            height: canvasRect.height * scale
        )
    }
}
