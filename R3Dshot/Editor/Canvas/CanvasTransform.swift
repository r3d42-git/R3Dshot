import CoreGraphics

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
