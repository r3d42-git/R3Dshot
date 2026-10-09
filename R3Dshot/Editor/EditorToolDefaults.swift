import Foundation

/// Window-local styles applied when a new annotation is created.
struct EditorToolDefaults {
    var rectangle = ShapeStyle(fillColor: RGBAColor(red: 1, green: 0.22, blue: 0.2, alpha: 0))
    var ellipse = ShapeStyle(fillColor: RGBAColor(red: 1, green: 0.22, blue: 0.2, alpha: 0))
    var arrow = ArrowStyle(
        startPoint: NormalizedPoint(x: 0, y: 0),
        endPoint: NormalizedPoint(x: 1, y: 1)
    )
    var redaction = RedactionStyle()
    var marker = MarkerStyle(points: [])
    var text = TextStyle()
    var speechBubble = SpeechBubbleStyle()
    var stepNumber = StepNumberStyle(number: 1)
    var pixelate = PixelateStyle()
    var focus = FocusStyle()
}
