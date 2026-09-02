import CoreGraphics

struct CanvasTransform {
    let canvasSize: PixelSize
    let scale: CGFloat

    func canvasPoint(from viewPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(0, viewPoint.x / scale), canvasSize.cgSize.width),
            y: min(max(0, viewPoint.y / scale), canvasSize.cgSize.height)
        )
    }

    func viewRect(from canvasRect: CanvasRect) -> CGRect {
        CGRect(
            x: canvasRect.x * scale,
            y: canvasRect.y * scale,
            width: canvasRect.width * scale,
            height: canvasRect.height * scale
        )
    }
}
