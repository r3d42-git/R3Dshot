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

struct SpeechBubbleStyle: Codable, Equatable, Sendable {
    var textStyle = TextStyle(text: "Sprechblase", color: .black, fontSize: 24)
    var fillColor = RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.96)
    var strokeColor = RGBAColor.accentRed
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 14
    var tailPoint = NormalizedPoint(x: 0.25, y: 1.15)
}

/// The visual container for a numbered step marker.
///
/// Unknown values decode as a circle so a document created by a newer version
/// remains usable instead of failing to open in an older version of R3Dshot.
enum StepNumberShape: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case circle
    case square
    case roundedSquare

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .circle
    }
}

struct StepNumberStyle: Codable, Equatable, Sendable {
    var number: Int = 1
    var fillColor = RGBAColor.accentRed
    var textColor = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
    var shape: StepNumberShape = .circle
}

extension StepNumberStyle {
    private enum CodingKeys: String, CodingKey {
        case number
        case fillColor
        case textColor
        case shape
    }

    /// `shape` was introduced after the initial document format. Decode the
    /// missing property from older documents as the original circular marker.
    /// Older documents may contain a `fontSize` key; keyed decoding safely
    /// ignores it because step label size is now derived from marker bounds.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decodeIfPresent(Int.self, forKey: .number) ?? 1
        fillColor = try container.decodeIfPresent(RGBAColor.self, forKey: .fillColor) ?? .accentRed
        textColor = try container.decodeIfPresent(RGBAColor.self, forKey: .textColor)
            ?? RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
        shape = try container.decodeIfPresent(StepNumberShape.self, forKey: .shape) ?? .circle
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encode(fillColor, forKey: .fillColor)
        try container.encode(textColor, forKey: .textColor)
        try container.encode(shape, forKey: .shape)
    }
}

struct PixelateStyle: Codable, Equatable, Sendable {
    var blockSize: CGFloat = 14
}

struct FocusStyle: Codable, Equatable, Sendable {
    var blurRadius: CGFloat = 18
}

enum AnnotationPayload: Codable, Equatable, Sendable {
    case rectangle(ShapeStyle)
    case ellipse(ShapeStyle)
    case arrow(ArrowStyle)
    case redaction(RedactionStyle)
    case marker(MarkerStyle)
    case text(TextStyle)
    case speechBubble(SpeechBubbleStyle)
    case stepNumber(StepNumberStyle)
    case pixelate(PixelateStyle)
    case focus(FocusStyle)
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

enum CropAspectRatio: String, CaseIterable, Identifiable {
    case free
    case square
    case widescreen
    case standard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: "Frei"
        case .square: "1:1"
        case .widescreen: "16:9"
        case .standard: "4:3"
        }
    }

    var ratio: CGFloat? {
        switch self {
        case .free: nil
        case .square: 1
        case .widescreen: 16 / 9
        case .standard: 4 / 3
        }
    }

    /// Fits the requested ratio inside the current crop while retaining its
    /// centre. This never grows the crop beyond its former content.
    func constrainedBounds(_ bounds: CanvasRect, in canvasSize: PixelSize) -> CanvasRect {
        guard let ratio else {
            return bounds.clamped(to: canvasSize, minimumSize: 4)
        }

        let rect = bounds.cgRect.standardized
        guard rect.width > 0, rect.height > 0 else {
            return bounds.clamped(to: canvasSize, minimumSize: 4)
        }

        let size: CGSize
        if rect.width / rect.height > ratio {
            size = CGSize(width: rect.height * ratio, height: rect.height)
        } else {
            size = CGSize(width: rect.width, height: rect.width / ratio)
        }
        return CanvasRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        .clamped(to: canvasSize, minimumSize: 4)
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
