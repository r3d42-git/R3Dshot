import CoreGraphics
import CoreImage
import CoreText
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
        let sourcePixelSize = document.original.pixelSize
        let crop = document.crop.clamped(to: sourcePixelSize).boundsInCanvasPixels.cgRect
        let pixelSize = PixelSize(
            width: max(1, Int(crop.width.rounded())),
            height: max(1, Int(crop.height.rounded()))
        )
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
        context.saveGState()
        context.clip(to: canvasRect)
        context.translateBy(
            x: -crop.minX,
            y: -(sourcePixelSize.cgSize.height - crop.maxY)
        )
        context.draw(originalImage, in: CGRect(origin: .zero, size: sourcePixelSize.cgSize))
        drawAnnotations(
            document.elements,
            in: context,
            canvasHeight: sourcePixelSize.cgSize.height,
            coordinateOrigin: .bottomLeft
        )
        context.restoreGState()

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
        case let .text(style):
            drawText(style, in: drawingBounds, context: context)
        case let .speechBubble(style):
            drawSpeechBubble(style, in: drawingBounds, context: context, coordinateOrigin: coordinateOrigin)
        case let .stepNumber(style):
            context.setFillColor(style.fillColor.cgColor)
            drawStepNumberShape(style.shape, in: drawingBounds, context: context)
            drawStepNumberLabel(style, in: drawingBounds, context: context)
        case let .pixelate(style):
            applyPixelation(blockSize: style.blockSize, in: drawingBounds, context: context)
        case let .focus(style):
            applyFocus(radius: style.blurRadius, keeping: drawingBounds, context: context)
        }
    }

    private static func drawStepNumberShape(
        _ shape: StepNumberShape,
        in bounds: CGRect,
        context: CGContext
    ) {
        switch shape {
        case .circle:
            context.fillEllipse(in: bounds)
        case .square:
            context.fill(bounds)
        case .roundedSquare:
            let radius = min(bounds.width, bounds.height) * 0.22
            context.addPath(
                CGPath(
                    roundedRect: bounds,
                    cornerWidth: radius,
                    cornerHeight: radius,
                    transform: nil
                )
            )
            context.fillPath()
        }
    }

    /// Draws a step number from its actual glyph bounds rather than from a
    /// paragraph frame. This keeps narrow digits such as “1” optically centred
    /// and makes the label grow and shrink with its square marker.
    private static func drawStepNumberLabel(
        _ style: StepNumberStyle,
        in bounds: CGRect,
        context: CGContext
    ) {
        let markerSide = min(bounds.width, bounds.height)
        guard markerSide > 0 else { return }

        let inset = max(2, markerSide * (3 / 44))
        let labelBounds = bounds.insetBy(dx: inset, dy: inset)
        let preferredFontSize = max(1, markerSide * (24 / 44))
        let text = "\(style.number)"
        let preferredLine = stepNumberLine(
            text,
            fontSize: preferredFontSize,
            color: style.textColor
        )
        let preferredWidth = CGFloat(
            CTLineGetTypographicBounds(preferredLine, nil, nil, nil)
        )
        let fontSize = preferredFontSize * min(
            1,
            labelBounds.width / max(1, preferredWidth)
        )
        let line = stepNumberLine(text, fontSize: fontSize, color: style.textColor)
        let glyphBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        guard !glyphBounds.isNull else { return }
        context.textPosition = CGPoint(
            x: labelBounds.midX - glyphBounds.midX,
            y: labelBounds.midY - glyphBounds.midY
        )
        CTLineDraw(line, context)
    }

    private static func stepNumberLine(
        _ text: String,
        fontSize: CGFloat,
        color: RGBAColor
    ) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName(
                "SF Pro" as CFString,
                fontSize,
                nil
            ),
            kCTForegroundColorAttributeName as NSAttributedString.Key: color.cgColor
        ]
        return CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
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

    private static func drawText(_ style: TextStyle, in bounds: CGRect, context: CGContext) {
        let paragraph = paragraphStyle(for: style.alignment)
        let attributes: [NSAttributedString.Key: Any] = [
            kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName(
                "SF Pro" as CFString,
                max(1, style.fontSize),
                nil
            ),
            kCTForegroundColorAttributeName as NSAttributedString.Key: style.color.cgColor,
            kCTParagraphStyleAttributeName as NSAttributedString.Key: paragraph
        ]
        let frame = CTFramesetterCreateFrame(
            CTFramesetterCreateWithAttributedString(NSAttributedString(string: style.text, attributes: attributes)),
            CFRange(location: 0, length: 0),
            CGPath(rect: bounds, transform: nil),
            nil
        )
        CTFrameDraw(frame, context)
    }

    private static func drawSpeechBubble(_ style: SpeechBubbleStyle, in bounds: CGRect, context: CGContext, coordinateOrigin: CoordinateOrigin) {
        let path = CGPath(roundedRect: bounds, cornerWidth: style.cornerRadius, cornerHeight: style.cornerRadius, transform: nil)
        context.addPath(path); context.setFillColor(style.fillColor.cgColor); context.fillPath()
        context.addPath(path); context.setStrokeColor(style.strokeColor.cgColor); context.setLineWidth(style.lineWidth); context.strokePath()
        let tip = drawingPoint(style.tailPoint, in: bounds, coordinateOrigin: coordinateOrigin)
        let baseY = bounds.minY
        let baseX = min(max(tip.x, bounds.minX + 14), bounds.maxX - 14)
        context.setFillColor(style.fillColor.cgColor)
        context.beginPath(); context.move(to: CGPoint(x: baseX - 10, y: baseY)); context.addLine(to: CGPoint(x: baseX + 10, y: baseY)); context.addLine(to: tip); context.closePath(); context.fillPath()
        context.setStrokeColor(style.strokeColor.cgColor); context.setLineWidth(style.lineWidth); context.beginPath(); context.move(to: CGPoint(x: baseX - 10, y: baseY)); context.addLine(to: tip); context.addLine(to: CGPoint(x: baseX + 10, y: baseY)); context.strokePath()
        drawText(style.textStyle, in: bounds.insetBy(dx: 12, dy: 10), context: context)
    }

    private static func applyPixelation(blockSize: CGFloat, in bounds: CGRect, context: CGContext) {
        guard let snapshot = context.makeImage() else { return }
        let input = CIImage(cgImage: snapshot)
        guard let filter = CIFilter(name: "CIPixellate") else { return }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(max(2, blockSize), forKey: kCIInputScaleKey)
        guard let output = filter.outputImage,
              let image = CIContext().createCGImage(output.cropped(to: input.extent), from: input.extent)
        else { return }
        drawEffect(image, snapshot: snapshot, clippedTo: bounds, in: context)
    }

    private static func applyFocus(radius: CGFloat, keeping bounds: CGRect, context: CGContext) {
        guard let snapshot = context.makeImage() else { return }
        let input = CIImage(cgImage: snapshot)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(max(1, radius), forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage,
              let blurred = CIContext().createCGImage(output.cropped(to: input.extent), from: input.extent)
        else { return }

        let snapshotBounds = snapshotBounds(for: snapshot, in: context)
        context.draw(blurred, in: snapshotBounds)
        context.saveGState()
        context.clip(to: bounds)
        context.draw(snapshot, in: snapshotBounds)
        context.restoreGState()
    }

    private static func drawEffect(
        _ image: CGImage,
        snapshot: CGImage,
        clippedTo bounds: CGRect,
        in context: CGContext
    ) {
        context.saveGState()
        context.clip(to: bounds)
        context.draw(image, in: snapshotBounds(for: snapshot, in: context))
        context.restoreGState()
    }

    private static func snapshotBounds(for snapshot: CGImage, in context: CGContext) -> CGRect {
        CGRect(x: 0, y: 0, width: snapshot.width, height: snapshot.height)
            .applying(context.ctm.inverted())
    }

    private static func paragraphStyle(for alignment: AnnotationTextAlignment) -> CTParagraphStyle {
        var textAlignment: CTTextAlignment
        switch alignment {
        case .leading: textAlignment = .left
        case .center: textAlignment = .center
        case .trailing: textAlignment = .right
        }
        var lineBreakMode = CTLineBreakMode.byWordWrapping
        return withUnsafePointer(to: &textAlignment) { alignmentPointer in
            withUnsafePointer(to: &lineBreakMode) { lineBreakPointer in
                CTParagraphStyleCreate(
                    [
                        CTParagraphStyleSetting(
                            spec: .alignment,
                            valueSize: MemoryLayout<CTTextAlignment>.size,
                            value: alignmentPointer
                        ),
                        CTParagraphStyleSetting(
                            spec: .lineBreakMode,
                            valueSize: MemoryLayout<CTLineBreakMode>.size,
                            value: lineBreakPointer
                        )
                    ],
                    2
                )
            }
        }
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
        case let .text(style): style.opacity
        case .speechBubble: 1
        case .stepNumber: 1
        case .pixelate, .focus: 1
        }
    }
}
