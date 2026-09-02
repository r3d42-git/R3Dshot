import CoreGraphics
import Foundation

enum ScreenshotRenderer {
    enum CoordinateOrigin {
        case topLeft
        case bottomLeft
    }

    enum RenderingError: LocalizedError {
        case couldNotCreateContext
        case couldNotCreateImage

        var errorDescription: String? {
            switch self {
            case .couldNotCreateContext:
                "Der Bildkontext für den Export konnte nicht erstellt werden."
            case .couldNotCreateImage:
                "Das bearbeitete Bild konnte nicht erzeugt werden."
            }
        }
    }

    static func render(document: ScreenshotDocument, originalImage: CGImage) throws -> CGImage {
        let pixelSize = document.original.pixelSize
        let colorSpace = originalImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: pixelSize.width,
            height: pixelSize.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RenderingError.couldNotCreateContext
        }

        let canvasRect = CGRect(origin: .zero, size: pixelSize.cgSize)
        context.interpolationQuality = .none
        context.draw(originalImage, in: canvasRect)
        drawAnnotations(
            document.elements,
            in: context,
            canvasHeight: pixelSize.cgSize.height,
            coordinateOrigin: .bottomLeft
        )

        guard let image = context.makeImage() else {
            throw RenderingError.couldNotCreateImage
        }
        return image
    }

    /// Draws annotations in a Quartz context. Document bounds use a top-left
    /// origin; Quartz uses a bottom-left origin, so the conversion lives here
    /// for both the editor preview and final export.
    static func drawAnnotations(
        _ elements: [AnnotationElement],
        in context: CGContext,
        canvasHeight: CGFloat,
        coordinateOrigin: CoordinateOrigin = .bottomLeft
    ) {
        for element in elements.sorted(by: { $0.zIndex < $1.zIndex }) {
            context.saveGState()
            context.setAlpha(elementOpacity(element))
            draw(
                element,
                in: context,
                canvasHeight: canvasHeight,
                coordinateOrigin: coordinateOrigin
            )
            context.restoreGState()
        }
    }

    private static func draw(
        _ element: AnnotationElement,
        in context: CGContext,
        canvasHeight: CGFloat,
        coordinateOrigin: CoordinateOrigin
    ) {
        let topLeftBounds = element.transform.boundsInCanvasPixels.cgRect
        let drawingBounds: CGRect
        switch coordinateOrigin {
        case .topLeft:
            drawingBounds = topLeftBounds
        case .bottomLeft:
            drawingBounds = CGRect(
                x: topLeftBounds.minX,
                y: canvasHeight - topLeftBounds.maxY,
                width: topLeftBounds.width,
                height: topLeftBounds.height
            )
        }

        switch element.payload {
        case let .rectangle(style):
            let radius = min(style.cornerRadius, min(drawingBounds.width, drawingBounds.height) / 2)
            let path = CGPath(
                roundedRect: drawingBounds,
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            )
            if style.fillColor.alpha > 0 {
                context.addPath(path)
                context.setFillColor(style.fillColor.cgColor)
                context.fillPath()
            }
            if style.strokeColor.alpha > 0, style.lineWidth > 0 {
                context.addPath(path)
                context.setStrokeColor(style.strokeColor.cgColor)
                context.setLineWidth(style.lineWidth)
                context.strokePath()
            }
        case let .ellipse(style):
            if style.fillColor.alpha > 0 {
                context.setFillColor(style.fillColor.cgColor)
                context.fillEllipse(in: drawingBounds)
            }
            if style.strokeColor.alpha > 0, style.lineWidth > 0 {
                context.setStrokeColor(style.strokeColor.cgColor)
                context.setLineWidth(style.lineWidth)
                context.strokeEllipse(in: drawingBounds)
            }
        case let .arrow(style):
            let start = drawingPoint(
                style.startPoint,
                in: drawingBounds,
                coordinateOrigin: coordinateOrigin
            )
            let end = drawingPoint(
                style.endPoint,
                in: drawingBounds,
                coordinateOrigin: coordinateOrigin
            )
            let headLength = max(style.arrowheadLength, style.lineWidth * 3)

            context.setStrokeColor(style.strokeColor.cgColor)
            context.setLineWidth(style.lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            if style.hasStartArrowhead {
                addArrowhead(
                    to: context,
                    at: start,
                    directionAngle: atan2(start.y - end.y, start.x - end.x),
                    length: headLength
                )
            }
            if style.hasEndArrowhead {
                addArrowhead(
                    to: context,
                    at: end,
                    directionAngle: atan2(end.y - start.y, end.x - start.x),
                    length: headLength
                )
            }
            context.strokePath()
        case let .redaction(style):
            context.setFillColor(style.color.cgColor)
            context.fill(drawingBounds)
        case let .marker(style):
            let points = style.points.map {
                drawingPoint($0, in: drawingBounds, coordinateOrigin: coordinateOrigin)
            }
            guard let first = points.first else { return }
            context.setStrokeColor(style.color.cgColor)
            context.setLineWidth(style.lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            context.move(to: first)
            for point in points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        }
    }

    private static func addArrowhead(
        to context: CGContext,
        at point: CGPoint,
        directionAngle: CGFloat,
        length: CGFloat
    ) {
        let spread = CGFloat.pi / 7
        let left = CGPoint(
            x: point.x - cos(directionAngle - spread) * length,
            y: point.y - sin(directionAngle - spread) * length
        )
        let right = CGPoint(
            x: point.x - cos(directionAngle + spread) * length,
            y: point.y - sin(directionAngle + spread) * length
        )
        context.move(to: left)
        context.addLine(to: point)
        context.addLine(to: right)
    }

    private static func drawingPoint(
        _ point: NormalizedPoint,
        in bounds: CGRect,
        coordinateOrigin: CoordinateOrigin
    ) -> CGPoint {
        CGPoint(
            x: bounds.minX + point.x * bounds.width,
            y: coordinateOrigin == .topLeft
                ? bounds.minY + point.y * bounds.height
                : bounds.maxY - point.y * bounds.height
        )
    }

    private static func elementOpacity(_ element: AnnotationElement) -> CGFloat {
        switch element.payload {
        case let .rectangle(style): style.opacity
        case let .ellipse(style): style.opacity
        case let .arrow(style): style.opacity
        case .redaction: 1
        case let .marker(style): style.opacity
        }
    }
}
