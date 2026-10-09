import AppKit

@main
struct EditorWorkflowSmoke {
    enum Failure: Error { case check(String) }
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw Failure.check(message) }
    }
    @MainActor
    static func main() throws {
        let context = CGContext(data: nil, width: 1200, height: 800, bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let image = context.makeImage()!
        let store = EditorStore(capture: PendingCapture(image: image, capturedAt: Date(),
                                                       source: .area(screenRectInPoints: .zero)))
        store.undoManager.groupsByEvent = false
        func edit(_ action: () -> Void) {
            store.undoManager.beginUndoGrouping()
            action()
            store.undoManager.endUndoGrouping()
        }
        let bounds = CanvasRect(x: 100, y: 100, width: 200, height: 100)
        let blue = RGBAColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1)
        store.markSaved(at: URL(fileURLWithPath: "/tmp/r3dshot-workflow-unwritten.png"))
        store.toolDefaults.rectangle.strokeColor = blue
        store.toolDefaults.rectangle.lineWidth = 9
        store.selectTool(.rectangle)
        try require(!store.hasUnsavedChanges && !store.undoManager.canUndo,
                    "Tool defaults and selection must not edit the document or undo history")
        edit { store.insertRectangle(in: bounds) }
        try require(store.selectedShapeStyle?.strokeColor == blue && store.selectedShapeStyle?.lineWidth == 9,
                    "New rectangle must use chosen defaults")
        store.undoManager.undo()
        try require(store.document.elements.isEmpty, "One undo removes the new annotation")
        store.undoManager.redo()
        try require(store.document.elements.count == 1, "Redo restores the annotation")
        store.selectTool(.ellipse)
        try require(!store.hasSelection && store.document.elements.count == 1,
                    "Choosing a drawing tool clears selection without deleting content")
        store.toolDefaults.ellipse.lineWidth = 7
        edit { store.insertEllipse(in: bounds) }
        try require(store.selectedShapeStyle?.lineWidth == 7, "Ellipse defaults independent of rectangle")
        store.toolDefaults.arrow.lineWidth = 8
        edit { store.insertArrow(from: CGPoint(x: 40,y: 30), to: CGPoint(x: 140,y: 130)) }
        try require(store.selectedArrowStyle?.lineWidth == 8, "Arrow adopts style")
        try require(store.selectedArrowStyle?.startPoint == NormalizedPoint(x: 0,y: 0) &&
                    store.selectedArrowStyle?.endPoint == NormalizedPoint(x: 1,y: 1), "Arrow retains drawn geometry")
        store.toolDefaults.marker.lineWidth = 33
        edit { store.insertMarker(points: [CGPoint(x: 30,y: 30),CGPoint(x: 130,y: 80)]) }
        try require(store.selectedMarkerStyle?.lineWidth == 33 && store.selectedMarkerStyle?.points.count == 2,
                    "Marker retains style and drawn points")
        store.toolDefaults.text.text = "Vorgabe"
        edit { store.insertText(in: bounds) }
        try require(store.selectedTextStyle?.text == "Vorgabe", "Text adopts content")
        store.toolDefaults.speechBubble.textStyle.text = "Hinweis"
        edit { store.insertSpeechBubble(in: bounds) }
        try require(store.selectedSpeechBubbleStyle?.textStyle.text == "Hinweis", "Speech bubble adopts content")
        store.toolDefaults.redaction.color = blue
        edit { store.insertRedaction(in: bounds) }
        try require(store.selectedRedactionStyle?.color == blue, "Redaction adopts color")
        store.toolDefaults.stepNumber.shape = .square
        store.toolDefaults.stepNumber.number = 999
        edit { store.setStepNumberStart(5) }
        edit { store.insertStepNumber(at: CGPoint(x: 100,y: 100)) }
        try require(store.selectedStepNumberStyle?.number == 5 && store.selectedStepNumberStyle?.shape == .square,
                    "Step style must not override sequence numbering")
        edit { store.insertStepNumber(at: CGPoint(x: 200,y: 100)) }
        try require(store.selectedStepNumberStyle?.number == 6 && store.activeTool == .stepNumber,
                    "Step tool remains active and counts forward")
        store.toolDefaults.pixelate.blockSize = 22
        edit { store.insertPixelate(in: bounds) }
        try require(store.selectedPixelateStyle?.blockSize == 22, "Pixelation adopts chosen block size")
        store.toolDefaults.focus.blurRadius = 32
        edit { store.insertFocus(in: bounds) }
        try require(store.selectedFocusStyle?.blurRadius == 32, "Focus adopts chosen blur")

        let fit = CanvasZoom.fittedZoom(imageSize: CGSize(width: 1200,height: 800),
                                       viewportSize: CGSize(width: 664,height: 464),displayScale: 1)
        try require(abs(fit - 0.5) < 0.0001, "Fit accounts for canvas padding")
        let retinaFit = CanvasZoom.fittedZoom(imageSize: CGSize(width: 1200,height: 800),
                                             viewportSize: CGSize(width: 664,height: 464),displayScale: 2)
        try require(retinaFit == 1 && CanvasZoom.viewScale(zoom: 1,displayScale: 2) == 0.5,
                    "Retina 100% maps one source pixel to one physical display pixel")
        try require(CanvasZoom.fittedZoom(imageSize: CGSize(width: 100,height: 100),
                                         viewportSize: CGSize(width: 1200,height: 800),displayScale: 1) == 1,
                    "Fit must not enlarge small images")
        store.updateCanvasFitZoom(fit)
        store.zoomIn()
        try require(!store.isZoomFitted && abs(store.effectiveZoom - 0.625) < 0.0001,
                    "Zoom begins at the actual fit scale")
        store.updateCanvasFitZoom(0.3)
        try require(abs(store.effectiveZoom - 0.625) < 0.0001, "Explicit zoom survives window resizing")
        store.showActualSize()
        try require(store.effectiveZoom == 1, "100% is independent of fit")
        store.fitCanvas()
        try require(store.effectiveZoom == 0.3, "Fit follows current viewport")

        func key(_ characters: String, modifiers: NSEvent.ModifierFlags, code: UInt16) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                            windowNumber: 0, context: nil, characters: characters,
                            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
        }
        try require(EditorKeyboardAction.resolve(key("c", modifiers: .command, code: 8)) == .copy, "Copy shortcut")
        try require(EditorKeyboardAction.resolve(key("z", modifiers: [.command,.shift], code: 6)) == .redo, "Redo shortcut")
        try require(EditorKeyboardAction.resolve(key("x", modifiers: .command, code: 7)) == nil, "Unhandled keys pass through")
        try require(EditorKeyboardAction.resolve(key("", modifiers: [], code: 51)) == .delete, "Delete key")
        print("Editor workflow smoke test passed (defaults, undo, numbering, zoom, shortcuts)")
    }
}
