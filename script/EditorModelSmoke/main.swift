import CoreGraphics
import Foundation

private enum SmokeFailure: Error {
    case couldNotCreateImage
    case assertion(String)
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw SmokeFailure.assertion(message) }
}

private func makeOriginalImage(width: Int, height: Int) throws -> CGImage {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: 0,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
    else {
        throw SmokeFailure.couldNotCreateImage
    }

    for y in 0..<height {
        for x in 0..<width {
            context.setFillColor(
                CGColor(
                    red: CGFloat((x * 29 + y * 11) % 256) / 255,
                    green: CGFloat((x * 7 + y * 31) % 256) / 255,
                    blue: CGFloat((x * 17 + y * 13) % 256) / 255,
                    alpha: 1
                )
            )
            context.fill(CGRect(x: x, y: y, width: 1, height: 1))
        }
    }
    guard let image = context.makeImage() else {
        throw SmokeFailure.couldNotCreateImage
    }
    return image
}

private func pixelBytes(_ image: CGImage) throws -> [UInt8] {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil,
              width: image.width,
              height: image.height,
              bitsPerComponent: 8,
              bytesPerRow: image.width * 4,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ),
          let data = context.data
    else {
        throw SmokeFailure.couldNotCreateImage
    }

    context.translateBy(x: 0, y: CGFloat(image.height))
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

    return Array(
        UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self),
            count: image.width * image.height * 4
        )
    )
}

private func changedPixelCount(
    between first: CGImage,
    and second: CGImage,
    in bounds: CanvasRect
) throws -> Int {
    try require(first.width == second.width && first.height == second.height, "Compared images have different dimensions")
    let firstBytes = try pixelBytes(first)
    let secondBytes = try pixelBytes(second)
    let imageBounds = CGRect(x: 0, y: 0, width: first.width, height: first.height)
    let inspected = bounds.cgRect.integral.intersection(imageBounds)
    guard !inspected.isNull else { return 0 }

    var changed = 0
    for y in Int(inspected.minY)..<Int(inspected.maxY) {
        for x in Int(inspected.minX)..<Int(inspected.maxX) {
            let offset = (y * first.width + x) * 4
            if firstBytes[offset..<(offset + 4)] != secondBytes[offset..<(offset + 4)] {
                changed += 1
            }
        }
    }
    return changed
}

private func changedPixelCountOutside(
    between first: CGImage,
    and second: CGImage,
    excluding bounds: CanvasRect
) throws -> Int {
    try require(first.width == second.width && first.height == second.height, "Compared images have different dimensions")
    let firstBytes = try pixelBytes(first)
    let secondBytes = try pixelBytes(second)
    let excluded = bounds.cgRect

    var changed = 0
    for y in 0..<first.height {
        for x in 0..<first.width where !excluded.contains(
            CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
        ) {
            let offset = (y * first.width + x) * 4
            if firstBytes[offset..<(offset + 4)] != secondBytes[offset..<(offset + 4)] {
                changed += 1
            }
        }
    }
    return changed
}

let original = try makeOriginalImage(width: 64, height: 48)
let originalBytesBefore = original.dataProvider?.data as Data?

var document = ScreenshotDocument(captureID: UUID(), image: original)
document.elements = [
    AnnotationElement(
        zIndex: 1,
        transform: ElementTransform(
            boundsInCanvasPixels: CanvasRect(x: 8, y: 6, width: 28, height: 20)
        ),
        payload: .rectangle(
            ShapeStyle(
                strokeColor: .accentRed,
                fillColor: RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.2),
                lineWidth: 4,
                cornerRadius: 3,
                opacity: 1
            )
        )
    ),
    AnnotationElement(
        zIndex: 0,
        transform: ElementTransform(
            boundsInCanvasPixels: CanvasRect(x: 2, y: 2, width: 12, height: 10)
        ),
        payload: .rectangle(ShapeStyle(lineWidth: 2))
    ),
    AnnotationElement(
        zIndex: 2,
        transform: ElementTransform(
            boundsInCanvasPixels: CanvasRect(x: 38, y: 14, width: 18, height: 22)
        ),
        payload: .ellipse(ShapeStyle(lineWidth: 2))
    ),
    AnnotationElement(
        zIndex: 3,
        transform: ElementTransform(
            boundsInCanvasPixels: CanvasRect(x: 12, y: 34, width: 40, height: 8)
        ),
        payload: .arrow(
            ArrowStyle(
                lineWidth: 3,
                arrowheadLength: 9,
                hasStartArrowhead: true,
                hasEndArrowhead: true,
                startPoint: NormalizedPoint(x: 0, y: 1),
                endPoint: NormalizedPoint(x: 1, y: 0)
            )
        )
    ),
    AnnotationElement(
        zIndex: 4,
        transform: ElementTransform(
            boundsInCanvasPixels: CanvasRect(x: 4, y: 38, width: 14, height: 6)
        ),
        payload: .redaction(RedactionStyle())
    ),
    AnnotationElement(
        zIndex: 5,
        transform: ElementTransform(
            boundsInCanvasPixels: CanvasRect(x: 20, y: 4, width: 34, height: 12)
        ),
        payload: .marker(
            MarkerStyle(
                points: [
                    NormalizedPoint(x: 0, y: 0.8),
                    NormalizedPoint(x: 0.4, y: 0.2),
                    NormalizedPoint(x: 1, y: 0.7)
                ]
            )
        )
    ),
    AnnotationElement(
        zIndex: 6,
        transform: ElementTransform(
            boundsInCanvasPixels: CanvasRect(x: 24, y: 20, width: 30, height: 18)
        ),
        payload: .text(
            TextStyle(text: "R3D", color: .accentRed, fontSize: 14, alignment: .center)
        )
    )
]

let encoded = try JSONEncoder().encode(document)
let decoded = try JSONDecoder().decode(ScreenshotDocument.self, from: encoded)
try require(decoded == document, "ScreenshotDocument Codable round-trip failed")

let rendered = try ScreenshotRenderer.render(document: document, originalImage: original)
try require(rendered.width == 64 && rendered.height == 48, "Renderer changed output dimensions")

document.crop = CropState(
    boundsInCanvasPixels: CanvasRect(x: 8, y: 6, width: 40, height: 30)
)
let cropped = try ScreenshotRenderer.render(document: document, originalImage: original)
try require(cropped.width == 40 && cropped.height == 30, "Renderer did not export crop dimensions")
try require(
    document.crop.boundsInCanvasPixels == CanvasRect(x: 8, y: 6, width: 40, height: 30),
    "Renderer changed the document crop"
)

try require(
    original.dataProvider?.data as Data? == originalBytesBefore,
    "Renderer modified the original image"
)
try require(document.elements.map(\.zIndex) == [1, 0, 2, 3, 4, 5, 6], "Renderer reordered document elements")

var effectDocument = ScreenshotDocument(captureID: UUID(), image: original)
effectDocument.crop = CropState(
    boundsInCanvasPixels: CanvasRect(x: 8, y: 6, width: 40, height: 30)
)
let effectBaseline = try ScreenshotRenderer.render(document: effectDocument, originalImage: original)
let effectBounds = CanvasRect(x: 16, y: 14, width: 16, height: 12)
let croppedEffectBounds = CanvasRect(
    x: effectBounds.x - effectDocument.crop.boundsInCanvasPixels.x,
    y: effectDocument.crop.boundsInCanvasPixels.cgRect.maxY - effectBounds.cgRect.maxY,
    width: effectBounds.width,
    height: effectBounds.height
)

var pixelatedDocument = effectDocument
pixelatedDocument.elements = [
    AnnotationElement(
        zIndex: 0,
        transform: ElementTransform(boundsInCanvasPixels: effectBounds),
        payload: .pixelate(PixelateStyle(blockSize: 6))
    )
]
let copiedPixelate = try JSONDecoder().decode(
    AnnotationElement.self,
    from: JSONEncoder().encode(pixelatedDocument.elements[0])
)
try require(
    copiedPixelate == pixelatedDocument.elements[0],
    "Pixelation annotation Codable round-trip failed"
)
let pixelated = try ScreenshotRenderer.render(document: pixelatedDocument, originalImage: original)
let pixelatedChangedInside = try changedPixelCount(
    between: pixelated,
    and: effectBaseline,
    in: croppedEffectBounds
)
try require(
    pixelatedChangedInside > 0,
    "Pixelation did not alter pixels inside its selected area"
)
let pixelatedChangedOutside = try changedPixelCountOutside(
    between: pixelated,
    and: effectBaseline,
    excluding: croppedEffectBounds
)
try require(
    pixelatedChangedOutside == 0,
    "Pixelation changed pixels outside its selected area"
)

var focusedDocument = effectDocument
focusedDocument.elements = [
    AnnotationElement(
        zIndex: 0,
        transform: ElementTransform(boundsInCanvasPixels: effectBounds),
        payload: .focus(FocusStyle(blurRadius: 8))
    )
]
let copiedFocus = try JSONDecoder().decode(
    AnnotationElement.self,
    from: JSONEncoder().encode(focusedDocument.elements[0])
)
try require(
    copiedFocus == focusedDocument.elements[0],
    "Focus annotation Codable round-trip failed"
)
let focused = try ScreenshotRenderer.render(document: focusedDocument, originalImage: original)
let sharpInterior = CanvasRect(
    x: croppedEffectBounds.x + 2,
    y: croppedEffectBounds.y + 2,
    width: croppedEffectBounds.width - 4,
    height: croppedEffectBounds.height - 4
)
let focusedChangedInside = try changedPixelCount(
    between: focused,
    and: effectBaseline,
    in: sharpInterior
)
try require(
    focusedChangedInside == 0,
    "Focus blurred pixels inside its selected area"
)
let focusedChangedOutside = try changedPixelCountOutside(
    between: focused,
    and: effectBaseline,
    excluding: croppedEffectBounds
)
try require(
    focusedChangedOutside > 0,
    "Focus did not blur pixels outside its selected area"
)

print("Editor model/renderer smoke test passed")
