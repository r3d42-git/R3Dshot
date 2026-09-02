import CoreGraphics
import Foundation

struct PixelSize: Codable, Equatable, Sendable {
    let width: Int
    let height: Int

    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

struct CanvasRect: Codable, Equatable, Sendable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: CGRect) {
        let standardized = rect.standardized
        self.init(
            x: standardized.minX,
            y: standardized.minY,
            width: standardized.width,
            height: standardized.height
        )
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    func clamped(to size: PixelSize, minimumSize: CGFloat = 1) -> CanvasRect {
        let canvas = CGRect(origin: .zero, size: size.cgSize)
        let proposed = cgRect.standardized
        let width = min(canvas.width, max(minimumSize, proposed.width))
        let height = min(canvas.height, max(minimumSize, proposed.height))
        let x = min(max(canvas.minX, proposed.minX), canvas.maxX - width)
        let y = min(max(canvas.minY, proposed.minY), canvas.maxY - height)
        return CanvasRect(x: x, y: y, width: width, height: height)
    }
}

struct RGBAColor: Codable, Equatable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    static let accentRed = RGBAColor(red: 1, green: 0.22, blue: 0.2, alpha: 1)
    static let markerYellow = RGBAColor(red: 1, green: 0.84, blue: 0.12, alpha: 1)
    static let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

struct ElementTransform: Codable, Equatable, Sendable {
    var boundsInCanvasPixels: CanvasRect
    var rotationRadians: CGFloat = 0
}

struct ShapeStyle: Codable, Equatable, Sendable {
    var strokeColor: RGBAColor = .accentRed
    var fillColor: RGBAColor = .clear
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 0
    var opacity: CGFloat = 1
}

struct NormalizedPoint: Codable, Equatable, Sendable {
    var x: CGFloat
    var y: CGFloat

    func point(in bounds: CanvasRect) -> CGPoint {
        CGPoint(
            x: bounds.x + x * bounds.width,
            y: bounds.y + y * bounds.height
        )
    }
}

struct ArrowStyle: Codable, Equatable, Sendable {
    var strokeColor: RGBAColor = .accentRed
    var lineWidth: CGFloat = 2
    var arrowheadLength: CGFloat = 18
    var opacity: CGFloat = 1
    var hasStartArrowhead = false
    var hasEndArrowhead = true
    var startPoint: NormalizedPoint
    var endPoint: NormalizedPoint
}

struct RedactionStyle: Codable, Equatable, Sendable {
    var color: RGBAColor = .black
}

struct MarkerStyle: Codable, Equatable, Sendable {
    var color: RGBAColor = .markerYellow
    var lineWidth: CGFloat = 20
    var opacity: CGFloat = 0.38
    var points: [NormalizedPoint]
}

enum AnnotationTextAlignment: String, Codable, CaseIterable, Sendable {
    case leading
    case center
    case trailing
}

struct TextStyle: Codable, Equatable, Sendable {
    var text: String = "Text"
    var color: RGBAColor = .accentRed
    var fontSize: CGFloat = 28
    var alignment: AnnotationTextAlignment = .leading
    var opacity: CGFloat = 1
}

enum AnnotationPayload: Codable, Equatable, Sendable {
    case rectangle(ShapeStyle)
    case ellipse(ShapeStyle)
    case arrow(ArrowStyle)
    case redaction(RedactionStyle)
    case marker(MarkerStyle)
    case text(TextStyle)
}

struct AnnotationElement: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var zIndex: Int
    var transform: ElementTransform
    var payload: AnnotationPayload

    init(
        id: UUID = UUID(),
        zIndex: Int,
        transform: ElementTransform,
        payload: AnnotationPayload
    ) {
        self.id = id
        self.zIndex = zIndex
        self.transform = transform
        self.payload = payload
    }
}

struct OriginalImageReference: Codable, Equatable, Sendable {
    let captureID: UUID
    let pixelSize: PixelSize
    let colorSpaceName: String?
}

struct CropState: Codable, Equatable, Sendable {
    var boundsInCanvasPixels: CanvasRect

    func clamped(to size: PixelSize) -> CropState {
        CropState(boundsInCanvasPixels: boundsInCanvasPixels.clamped(to: size, minimumSize: 4))
    }

    static func fullImage(_ size: PixelSize) -> CropState {
        CropState(
            boundsInCanvasPixels: CanvasRect(
                x: 0,
                y: 0,
                width: size.cgSize.width,
                height: size.cgSize.height
            )
        )
    }
}

struct ScreenshotDocument: Identifiable, Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    let id: UUID
    let original: OriginalImageReference
    var crop: CropState
    var elements: [AnnotationElement]
    var formatVersion: Int

    init(captureID: UUID, image: CGImage) {
        let pixelSize = PixelSize(width: image.width, height: image.height)
        self.id = UUID()
        self.original = OriginalImageReference(
            captureID: captureID,
            pixelSize: pixelSize,
            colorSpaceName: image.colorSpace?.name as String?
        )
        self.crop = .fullImage(pixelSize)
        self.elements = []
        self.formatVersion = Self.currentFormatVersion
    }
}
