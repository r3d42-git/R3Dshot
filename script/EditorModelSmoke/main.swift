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

private func makeSolidImage(width: Int, height: Int, color: CGColor) throws -> CGImage {
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

    context.setFillColor(color)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
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

private func brightPixelBounds(in image: CGImage, within bounds: CanvasRect) throws -> CGRect? {
    let bytes = try pixelBytes(image)
    let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    let inspected = bounds.cgRect.integral.intersection(imageBounds)
    guard !inspected.isNull, !inspected.isEmpty else { return nil }

    var minX: Int?
    var minY: Int?
    var maxX: Int?
    var maxY: Int?
    for y in Int(inspected.minY)..<Int(inspected.maxY) {
        for x in Int(inspected.minX)..<Int(inspected.maxX) {
            let offset = (y * image.width + x) * 4
            guard bytes[offset] > 220, bytes[offset + 1] > 220, bytes[offset + 2] > 220 else { continue }
            minX = min(minX ?? x, x)
            minY = min(minY ?? y, y)
            maxX = max(maxX ?? x, x)
            maxY = max(maxY ?? y, y)
        }
    }

    guard let minX, let minY, let maxX, let maxY else { return nil }
    return CGRect(
        x: minX,
        y: minY,
        width: maxX - minX + 1,
        height: maxY - minY + 1
    )
}

private func redPixelBounds(in image: CGImage) throws -> CGRect? {
    let bytes = try pixelBytes(image)
    var minX: Int?
    var minY: Int?
    var maxX: Int?
    var maxY: Int?
    for y in 0..<image.height {
        for x in 0..<image.width {
            let offset = (y * image.width + x) * 4
            guard bytes[offset] > 220, bytes[offset + 1] < 180, bytes[offset + 2] < 180 else { continue }
            minX = min(minX ?? x, x)
            minY = min(minY ?? y, y)
            maxX = max(maxX ?? x, x)
            maxY = max(maxY ?? y, y)
        }
    }
    guard let minX, let minY, let maxX, let maxY else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
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

let roundedStepStyle = StepNumberStyle(number: 5, shape: .roundedSquare)
let copiedRoundedStepStyle = try JSONDecoder().decode(
    StepNumberStyle.self,
    from: JSONEncoder().encode(roundedStepStyle)
)
try require(
    copiedRoundedStepStyle == roundedStepStyle,
    "Step number shape Codable round-trip failed"
)

var legacyStepStyleObject = try requireJSONDictionary(from: JSONEncoder().encode(roundedStepStyle))
legacyStepStyleObject.removeValue(forKey: "shape")
let legacyStepStyle = try JSONDecoder().decode(
    StepNumberStyle.self,
    from: JSONSerialization.data(withJSONObject: legacyStepStyleObject)
)
try require(
    legacyStepStyle.shape == .circle,
    "Legacy step number styles without a shape did not default to a circle"
)

var manuallySizedLegacyStepStyleObject = try requireJSONDictionary(
    from: JSONEncoder().encode(roundedStepStyle)
)
manuallySizedLegacyStepStyleObject["fontSize"] = 96
let manuallySizedLegacyStepStyle = try JSONDecoder().decode(
    StepNumberStyle.self,
    from: JSONSerialization.data(withJSONObject: manuallySizedLegacyStepStyleObject)
)
try require(
    manuallySizedLegacyStepStyle == roundedStepStyle,
    "Legacy step marker font size was not ignored during automatic-size migration"
)
let automaticallySizedStepStyleObject = try requireJSONDictionary(
    from: JSONEncoder().encode(manuallySizedLegacyStepStyle)
)
try require(
    automaticallySizedStepStyleObject["fontSize"] == nil,
    "Automatic step marker styles unexpectedly encode a manual font size"
)

var futureStepStyleObject = try requireJSONDictionary(from: JSONEncoder().encode(roundedStepStyle))
futureStepStyleObject["shape"] = "futureShape"
let futureStepStyle = try JSONDecoder().decode(
    StepNumberStyle.self,
    from: JSONSerialization.data(withJSONObject: futureStepStyleObject)
)
try require(
    futureStepStyle.shape == .circle,
    "Unknown future step number shapes did not fall back to a circle"
)

let fullCropBounds = CanvasRect(x: 0, y: 0, width: 64, height: 48)
let cropCanvasSize = PixelSize(width: 64, height: 48)
for (aspectRatio, expectedRatio) in [
    (CropAspectRatio.square, CGFloat(1)),
    (.widescreen, CGFloat(16) / 9),
    (.standard, CGFloat(4) / 3)
] {
    let constrainedCrop = aspectRatio.constrainedBounds(
        fullCropBounds,
        in: cropCanvasSize
    )
    try require(
        abs(constrainedCrop.width / constrainedCrop.height - expectedRatio) < 0.0001,
        "Crop ratio \(aspectRatio.rawValue) was not preserved"
    )
    try require(
        abs(constrainedCrop.cgRect.midX - fullCropBounds.cgRect.midX) < 0.0001
            && abs(constrainedCrop.cgRect.midY - fullCropBounds.cgRect.midY) < 0.0001,
        "Crop ratio \(aspectRatio.rawValue) did not retain the crop centre"
    )
}
try require(
    CropAspectRatio.free.constrainedBounds(fullCropBounds, in: cropCanvasSize) == fullCropBounds,
    "Freeform crop unexpectedly changed its bounds"
)

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

let fullImageBounds = CanvasRect(x: 0, y: 0, width: 64, height: 48)
let stepBounds = CanvasRect(x: 20, y: 10, width: 24, height: 24)
let baselineStepDocument = ScreenshotDocument(captureID: UUID(), image: original)
let baselineStepRender = try ScreenshotRenderer.render(
    document: baselineStepDocument,
    originalImage: original
)

func renderedStepMarker(shape: StepNumberShape) throws -> CGImage {
    var stepDocument = ScreenshotDocument(captureID: UUID(), image: original)
    stepDocument.elements = [
        AnnotationElement(
            zIndex: 0,
            transform: ElementTransform(boundsInCanvasPixels: stepBounds),
            payload: .stepNumber(
                StepNumberStyle(number: 5, fillColor: .accentRed, shape: shape)
            )
        )
    ]
    return try ScreenshotRenderer.render(document: stepDocument, originalImage: original)
}

let circularStepRender = try renderedStepMarker(shape: .circle)
let squareStepRender = try renderedStepMarker(shape: .square)
let roundedSquareStepRender = try renderedStepMarker(shape: .roundedSquare)
for (shape, render) in [
    (StepNumberShape.circle, circularStepRender),
    (.square, squareStepRender),
    (.roundedSquare, roundedSquareStepRender)
] {
    let changedPixels = try changedPixelCount(
        between: render,
        and: baselineStepRender,
        in: fullImageBounds
    )
    try require(
        changedPixels > 0,
        "Step number \(shape.rawValue) did not render visible output"
    )
}
let circularVsSquareChangedPixels = try changedPixelCount(
    between: circularStepRender,
    and: squareStepRender,
    in: fullImageBounds
)
try require(
    circularVsSquareChangedPixels > 0,
    "Circular and square step number renderings are indistinguishable"
)
let squareVsRoundedSquareChangedPixels = try changedPixelCount(
    between: squareStepRender,
    and: roundedSquareStepRender,
    in: fullImageBounds
)
try require(
    squareVsRoundedSquareChangedPixels > 0,
    "Square and rounded-square step number renderings are indistinguishable"
)
let circularVsRoundedSquareChangedPixels = try changedPixelCount(
    between: circularStepRender,
    and: roundedSquareStepRender,
    in: fullImageBounds
)
try require(
    circularVsRoundedSquareChangedPixels > 0,
    "Circular and rounded-square step number renderings are indistinguishable"
)

func renderedCenteredStepMarker(
    number: Int,
    side: CGFloat
) throws -> (image: CGImage, markerBounds: CanvasRect) {
    let original = try makeSolidImage(
        width: 160,
        height: 160,
        color: CGColor(gray: 0, alpha: 1)
    )
    let markerBounds = CanvasRect(x: 48, y: 48, width: side, height: side)
    var document = ScreenshotDocument(captureID: UUID(), image: original)
    document.elements = [
        AnnotationElement(
            zIndex: 0,
            transform: ElementTransform(boundsInCanvasPixels: markerBounds),
            payload: .stepNumber(
                StepNumberStyle(number: number, fillColor: .accentRed, shape: .square)
            )
        )
    ]
    return (
        try ScreenshotRenderer.render(document: document, originalImage: original),
        markerBounds
    )
}

func labelBounds(of marker: (image: CGImage, markerBounds: CanvasRect)) throws -> (label: CGRect, marker: CGRect) {
    guard let renderedMarker = try redPixelBounds(in: marker.image) else {
        throw SmokeFailure.assertion("Step marker did not render red pixels")
    }
    let renderedMarkerCanvasRect = CanvasRect(
        x: renderedMarker.minX,
        y: renderedMarker.minY,
        width: renderedMarker.width,
        height: renderedMarker.height
    )
    guard let label = try brightPixelBounds(in: marker.image, within: renderedMarkerCanvasRect) else {
        throw SmokeFailure.assertion("Step number label did not render bright pixels")
    }
    return (label, renderedMarker)
}

for number in [1, 3, 8, 12, 9999] {
    let marker = try renderedCenteredStepMarker(number: number, side: 44)
    let rendered = try labelBounds(of: marker)
    let label = rendered.label
    let markerRect = rendered.marker
    try require(
        abs(label.midX - markerRect.midX) <= 2.5
            && abs(label.midY - markerRect.midY) <= 1.5,
        "Step number \(number) was not optically centred (label: \(label), marker: \(markerRect))"
    )
    try require(
        label.minX >= markerRect.minX + 1
            && label.maxX <= markerRect.maxX - 1,
        "Step number \(number) did not fit inside its marker"
    )
}

let smallLabel = try labelBounds(of: try renderedCenteredStepMarker(number: 8, side: 24)).label
let standardLabel = try labelBounds(of: try renderedCenteredStepMarker(number: 8, side: 44)).label
let largeLabel = try labelBounds(of: try renderedCenteredStepMarker(number: 8, side: 80)).label
try require(
    standardLabel.height > smallLabel.height * 1.45
        && largeLabel.height > standardLabel.height * 1.45,
    "Step number label did not scale with marker size"
)

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

private func requireJSONDictionary(from data: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw SmokeFailure.assertion("Expected a JSON object")
    }
    return object
}
