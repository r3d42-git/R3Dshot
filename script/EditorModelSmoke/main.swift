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

    context.setFillColor(CGColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else {
        throw SmokeFailure.couldNotCreateImage
    }
    return image
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
try require(document.elements.map(\.zIndex) == [1, 0, 2, 3, 4, 5], "Renderer reordered document elements")

print("Editor model/renderer smoke test passed")
