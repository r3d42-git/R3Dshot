import AppKit
import Observation

enum EditorTool: String, CaseIterable, Identifiable {
    case select
    case crop
    case rectangle
    case ellipse
    case arrow
    case redaction
    case marker
    case text
    case speechBubble
    case stepNumber
    case pixelate
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Auswahl"
        case .crop: "Zuschneiden"
        case .rectangle: "Rechteck"
        case .ellipse: "Ellipse"
        case .arrow: "Pfeil"
        case .redaction: "Schwärzen"
        case .marker: "Marker"
        case .text: "Text"
        case .speechBubble: "Sprechblase"
        case .stepNumber: "Schritt"
        case .pixelate: "Pixelieren"
        case .focus: "Fokus"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "arrow.up.left"
        case .crop: "crop"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .arrow: "arrow.up.right"
        case .redaction: "rectangle.fill"
        case .marker: "highlighter"
        case .text: "text.cursor"
        case .speechBubble: "text.bubble"
        case .stepNumber: "1.circle"
        case .pixelate: "square.grid.3x3"
        case .focus: "viewfinder"
        }
    }

    var helpText: String {
        switch self {
        case .select: "Auswahlwerkzeug – Elemente auswählen, verschieben und skalieren"
        case .crop: "Zuschneiden – den sichtbaren Bildausschnitt aufziehen oder anpassen"
        case .rectangle: "Rechteckwerkzeug – ein Rechteck aufziehen"
        case .ellipse: "Ellipsenwerkzeug – eine Ellipse aufziehen"
        case .arrow: "Pfeilwerkzeug – vom Startpunkt zur Pfeilspitze ziehen"
        case .redaction: "Schwärzen – einen Bereich vollständig und dauerhaft sichtbar abdecken"
        case .marker: "Marker – einen Bereich freihändig transparent hervorheben"
        case .text: "Text – einen editierbaren Textbereich aufziehen"
        case .speechBubble: "Sprechblase – einen beschrifteten Hinweis aufziehen"
        case .stepNumber: "Schritt – eine nummerierte Markierung per Klick platzieren"
        case .pixelate: "Pixelieren – einen Bereich nicht-destruktiv verpixeln"
        case .focus: "Fokus – markierten Bereich scharf hervorheben"
        }
    }
}

struct EditorSession {
    let originalImage: CGImage
    let capturedAt: Date
    let source: CaptureSource
}

@MainActor
@Observable
final class EditorStore {
    private static let initialStepNumberSize: CGFloat = 44

    let session: EditorSession
    private(set) var document: ScreenshotDocument
    /// The complete, validated selection. Keep selection state separate from the
    /// document so choosing elements never marks an image as changed.
    private(set) var selectedElementIDs: Set<UUID> = []
    var activeTool: EditorTool = .select
    var zoom: CGFloat = 1
    var isInspectorPresented = true
    private(set) var savedURL: URL?
    /// The number assigned to the first step marker in a sequence.
    ///
    /// This is editor-session configuration rather than part of an annotation.
    /// Existing markers are rebased when it changes, preserving their order.
    private(set) var stepNumberStart: Int = 1

    @ObservationIgnored private var lastSavedDocument: ScreenshotDocument?

    @ObservationIgnored let undoManager = UndoManager()

    init(capture: PendingCapture) {
        session = EditorSession(
            originalImage: capture.image,
            capturedAt: capture.capturedAt,
            source: capture.source
        )
        document = ScreenshotDocument(captureID: capture.id, image: capture.image)
    }

    /// The single selected ID, or `nil` while no or multiple elements are selected.
    /// Keeping this compatibility surface lets single-element inspectors remain
    /// intentionally unavailable for a group selection.
    var selectedElementID: UUID? {
        guard selectedElementIDs.count == 1 else { return nil }
        return selectedElementIDs.first
    }

    /// The single selected element, or `nil` while no or multiple elements are selected.
    var selectedElement: AnnotationElement? {
        guard let selectedElementID else { return nil }
        return document.elements.first { $0.id == selectedElementID }
    }

    /// All selected elements in document order.
    var selectedElements: [AnnotationElement] {
        document.elements.filter { selectedElementIDs.contains($0.id) }
    }

    var selectionCount: Int {
        selectedElementIDs.count
    }

    var hasSelection: Bool {
        !selectedElementIDs.isEmpty
    }

    var hasSingleSelection: Bool {
        selectedElementID != nil
    }

    func isElementSelected(_ elementID: UUID) -> Bool {
        selectedElementIDs.contains(elementID)
    }

    /// The smallest canvas rect containing every selected element.
    var selectionBounds: CanvasRect? {
        guard let first = selectedElements.first else { return nil }
        let rect = selectedElements.dropFirst().reduce(first.transform.boundsInCanvasPixels.cgRect) {
            $0.union($1.transform.boundsInCanvasPixels.cgRect)
        }
        return CanvasRect(rect)
    }

    /// A stable drag snapshot for moving the current selection as one group.
    func selectedBoundsByElementID() -> [UUID: CanvasRect] {
        Dictionary(
            uniqueKeysWithValues: selectedElements.map {
                ($0.id, $0.transform.boundsInCanvasPixels)
            }
        )
    }

    var selectedShapeStyle: ShapeStyle? {
        switch selectedElement?.payload {
        case let .rectangle(style), let .ellipse(style): style
        case .arrow, .redaction, .marker, .text, .speechBubble, .stepNumber, .pixelate, .focus, nil: nil
        }
    }

    var selectedShapeTitle: String? {
        switch selectedElement?.payload {
        case .rectangle: "Rechteck"
        case .ellipse: "Ellipse"
        case .arrow: "Pfeil"
        case .redaction: "Schwärzung"
        case .marker: "Marker"
        case .text: "Text"
        case .speechBubble: "Sprechblase"
        case .stepNumber: "Schritt"
        case .pixelate: "Pixelierung"
        case .focus: "Fokus"
        case nil: nil
        }
    }

    var selectedShapeSupportsCornerRadius: Bool {
        guard case .rectangle = selectedElement?.payload else { return false }
        return true
    }

    var selectedArrowStyle: ArrowStyle? {
        guard case let .arrow(style)? = selectedElement?.payload else { return nil }
        return style
    }

    var selectedRedactionStyle: RedactionStyle? {
        guard case let .redaction(style)? = selectedElement?.payload else { return nil }
        return style
    }

    var selectedMarkerStyle: MarkerStyle? {
        guard case let .marker(style)? = selectedElement?.payload else { return nil }
        return style
    }

    var selectedTextStyle: TextStyle? {
        guard case let .text(style)? = selectedElement?.payload else { return nil }
        return style
    }

    var selectedSpeechBubbleStyle: SpeechBubbleStyle? {
        guard case let .speechBubble(style)? = selectedElement?.payload else { return nil }
        return style
    }

    var selectedStepNumberStyle: StepNumberStyle? {
        guard case let .stepNumber(style)? = selectedElement?.payload else { return nil }
        return style
    }

    /// Step marker styles when every selected annotation is a step marker.
    /// A mixed selection deliberately returns `nil`, so type-specific edits can
    /// never change unrelated annotation types by accident.
    var selectedStepNumberStyles: [StepNumberStyle]? {
        let elements = selectedElements
        guard !elements.isEmpty else { return nil }
        let styles = elements.compactMap { element -> StepNumberStyle? in
            guard case let .stepNumber(style) = element.payload else { return nil }
            return style
        }
        return styles.count == elements.count ? styles : nil
    }

    /// `nil` represents a mixed selection of step marker shapes.
    var selectedStepNumberShape: StepNumberShape? {
        guard let styles = selectedStepNumberStyles,
              let firstShape = styles.first?.shape,
              styles.dropFirst().allSatisfy({ $0.shape == firstShape })
        else { return nil }
        return firstShape
    }

    var selectedPixelateStyle: PixelateStyle? {
        guard case let .pixelate(style)? = selectedElement?.payload else { return nil }
        return style
    }

    var selectedFocusStyle: FocusStyle? {
        guard case let .focus(style)? = selectedElement?.payload else { return nil }
        return style
    }

    var stepNumberCount: Int {
        document.elements.reduce(into: 0) { count, element in
            if case .stepNumber = element.payload {
                count += 1
            }
        }
    }

    /// The number that will be assigned to the next inserted, pasted, or duplicated step.
    var nextStepNumber: Int {
        stepNumberStart + stepNumberCount
    }

    /// Valid displayed numbers for the existing sequence. It also supplies a
    /// useful one-value range before the first marker is inserted.
    var stepNumberRange: ClosedRange<Int> {
        stepNumberStart...max(stepNumberStart, nextStepNumber - 1)
    }

    var hasUnsavedChanges: Bool {
        lastSavedDocument != document
    }

    var cropBounds: CanvasRect {
        document.crop.boundsInCanvasPixels
    }

    func markSaved(at url: URL) {
        savedURL = url
        lastSavedDocument = document
    }

    func previewCrop(_ bounds: CanvasRect) {
        document.crop = CropState(boundsInCanvasPixels: bounds)
            .clamped(to: document.original.pixelSize)
    }

    func commitCropChange(from originalCrop: CropState, actionName: String) {
        guard document.crop != originalCrop else { return }
        var previous = document
        previous.crop = originalCrop
        registerChange(from: previous, to: document, actionName: actionName)
    }

    func setCrop(_ bounds: CanvasRect) {
        let crop = CropState(boundsInCanvasPixels: bounds)
            .clamped(to: document.original.pixelSize)
        perform(actionName: "Bild zuschneiden") {
            document.crop = crop
            activeTool = .select
        }
    }

    func resetCrop() {
        let fullCrop = CropState.fullImage(document.original.pixelSize)
        perform(actionName: "Zuschneiden zurücksetzen") {
            document.crop = fullCrop
        }
    }

    // MARK: - Selection

    func setSelection(_ elementIDs: Set<UUID>) {
        selectedElementIDs = validSelection(from: elementIDs)
    }

    func selectOnly(_ elementID: UUID?) {
        guard let elementID else {
            clearSelection()
            return
        }
        setSelection([elementID])
    }

    func addToSelection(_ elementID: UUID) {
        guard index(of: elementID) != nil else { return }
        selectedElementIDs.insert(elementID)
    }

    func toggleSelection(_ elementID: UUID) {
        guard index(of: elementID) != nil else { return }
        if selectedElementIDs.contains(elementID) {
            selectedElementIDs.remove(elementID)
        } else {
            selectedElementIDs.insert(elementID)
        }
    }

    func clearSelection() {
        selectedElementIDs.removeAll()
    }

    /// Selects the topmost element at a canvas point. With `additive`, a hit is
    /// added to the current group; with `toggling`, it is added or removed.
    /// A plain click on empty canvas clears the selection.
    @discardableResult
    func selectElement(
        at point: CGPoint,
        tolerance: CGFloat = 5,
        additive: Bool = false,
        toggling: Bool = false
    ) -> UUID? {
        let elementID = elementID(at: point, tolerance: tolerance)
        guard let elementID else {
            if !additive && !toggling {
                clearSelection()
            }
            return nil
        }

        if toggling {
            toggleSelection(elementID)
        } else if additive {
            addToSelection(elementID)
        } else {
            selectOnly(elementID)
        }
        return elementID
    }

    /// Previews a rigid group move. The passed snapshot should come from
    /// `selectedBoundsByElementID()` at the beginning of the drag.
    func previewMoveSelection(
        by translation: CGSize,
        from originalBounds: [UUID: CanvasRect]
    ) {
        let entries = validMoveEntries(from: originalBounds)
        guard !entries.isEmpty else { return }

        let translation = clampedSelectionTranslation(translation, for: entries.map(\.bounds))
        for entry in entries {
            guard let index = index(of: entry.id) else { continue }
            document.elements[index].transform.boundsInCanvasPixels = CanvasRect(
                x: entry.bounds.x + translation.width,
                y: entry.bounds.y + translation.height,
                width: entry.bounds.width,
                height: entry.bounds.height
            )
        }
    }

    /// Convenience overload for canvas drag code that already has scalar deltas.
    func previewMoveSelection(
        from originalBounds: [UUID: CanvasRect],
        dx: CGFloat,
        dy: CGFloat
    ) {
        previewMoveSelection(by: CGSize(width: dx, height: dy), from: originalBounds)
    }

    func commitMoveSelection(
        from originalBounds: [UUID: CanvasRect],
        actionName: String = "Auswahl verschieben"
    ) {
        let entries = validMoveEntries(from: originalBounds)
        guard entries.contains(where: { entry in
            document.elements[index(of: entry.id)!].transform.boundsInCanvasPixels != entry.bounds
        }) else { return }

        var previous = document
        for entry in entries {
            guard let index = previous.elements.firstIndex(where: { $0.id == entry.id }) else { continue }
            previous.elements[index].transform.boundsInCanvasPixels = entry.bounds
        }
        registerChange(from: previous, to: document, actionName: actionName)
    }

    func setStepNumberStart(_ number: Int, actionName: String = "Startnummer ändern") {
        let newStart = max(1, number)
        guard newStart != stepNumberStart else { return }

        let previousDocument = document
        let previousStart = stepNumberStart
        stepNumberStart = newStart
        normalizeStepNumbers()
        registerChange(
            from: previousDocument,
            to: document,
            actionName: actionName,
            previousStepNumberStart: previousStart,
            currentStepNumberStart: newStart
        )
    }

    func insertRectangle(in bounds: CanvasRect) {
        let clamped = bounds.clamped(to: document.original.pixelSize, minimumSize: 4)
        guard clamped.width >= 4, clamped.height >= 4 else { return }

        perform(actionName: "Rechteck hinzufügen") {
            let element = AnnotationElement(
                zIndex: nextZIndex,
                transform: ElementTransform(boundsInCanvasPixels: clamped),
                payload: .rectangle(ShapeStyle())
            )
            document.elements.append(element)
            selectOnly(element.id)
            activeTool = .select
        }
    }

    func insertEllipse(in bounds: CanvasRect) {
        let clamped = bounds.clamped(to: document.original.pixelSize, minimumSize: 4)
        guard clamped.width >= 4, clamped.height >= 4 else { return }

        perform(actionName: "Ellipse hinzufügen") {
            let element = AnnotationElement(
                zIndex: nextZIndex,
                transform: ElementTransform(boundsInCanvasPixels: clamped),
                payload: .ellipse(ShapeStyle())
            )
            document.elements.append(element)
            selectOnly(element.id)
            activeTool = .select
        }
    }

    func insertArrow(from start: CGPoint, to end: CGPoint) {
        guard hypot(end.x - start.x, end.y - start.y) >= 4 else { return }
        let geometry = arrowGeometry(start: start, end: end)

        perform(actionName: "Pfeil hinzufügen") {
            let element = AnnotationElement(
                zIndex: nextZIndex,
                transform: ElementTransform(boundsInCanvasPixels: geometry.bounds),
                payload: .arrow(
                    ArrowStyle(startPoint: geometry.start, endPoint: geometry.end)
                )
            )
            document.elements.append(element)
            selectOnly(element.id)
            activeTool = .select
        }
    }

    func insertRedaction(in bounds: CanvasRect) {
        let clamped = bounds.clamped(to: document.original.pixelSize, minimumSize: 4)
        guard clamped.width >= 4, clamped.height >= 4 else { return }

        perform(actionName: "Schwärzung hinzufügen") {
            let element = AnnotationElement(
                zIndex: nextZIndex,
                transform: ElementTransform(boundsInCanvasPixels: clamped),
                payload: .redaction(RedactionStyle())
            )
            document.elements.append(element)
            selectOnly(element.id)
            activeTool = .select
        }
    }

    func insertMarker(points: [CGPoint]) {
        guard points.count >= 2 else { return }
        let minimumSize: CGFloat = 4
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let width = max(minimumSize, maxX - minX)
        let height = max(minimumSize, maxY - minY)
        let rawBounds = CanvasRect(
            x: minX - max(0, minimumSize - (maxX - minX)) / 2,
            y: minY - max(0, minimumSize - (maxY - minY)) / 2,
            width: width,
            height: height
        )
        let bounds = rawBounds.clamped(to: document.original.pixelSize, minimumSize: minimumSize)
        let normalized = points.map { point in
            NormalizedPoint(
                x: min(1, max(0, (point.x - bounds.x) / bounds.width)),
                y: min(1, max(0, (point.y - bounds.y) / bounds.height))
            )
        }

        perform(actionName: "Marker hinzufügen") {
            let element = AnnotationElement(
                zIndex: nextZIndex,
                transform: ElementTransform(boundsInCanvasPixels: bounds),
                payload: .marker(MarkerStyle(points: normalized))
            )
            document.elements.append(element)
            selectOnly(element.id)
            activeTool = .select
        }
    }

    func insertText(in bounds: CanvasRect) {
        let clamped = bounds.clamped(to: document.original.pixelSize, minimumSize: 12)
        guard clamped.width >= 12, clamped.height >= 12 else { return }

        perform(actionName: "Text hinzufügen") {
            let element = AnnotationElement(
                zIndex: nextZIndex,
                transform: ElementTransform(boundsInCanvasPixels: clamped),
                payload: .text(TextStyle())
            )
            document.elements.append(element)
            selectOnly(element.id)
            activeTool = .select
        }
    }

    func insertSpeechBubble(in bounds: CanvasRect) {
        let clamped = bounds.clamped(to: document.original.pixelSize, minimumSize: 24)
        guard clamped.width >= 24, clamped.height >= 24 else { return }
        perform(actionName: "Sprechblase hinzufügen") {
            let element = AnnotationElement(zIndex: nextZIndex, transform: ElementTransform(boundsInCanvasPixels: clamped), payload: .speechBubble(SpeechBubbleStyle()))
            document.elements.append(element); selectOnly(element.id); activeTool = .select
        }
    }

    func insertStepNumber(at point: CGPoint) {
        let canvasSize = document.original.pixelSize.cgSize
        let size = min(Self.initialStepNumberSize, min(canvasSize.width, canvasSize.height))
        guard size >= 24 else { return }
        let bounds = CanvasRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size
        )
        .clamped(to: document.original.pixelSize, minimumSize: 24)

        perform(actionName: "Schritt hinzufügen") {
            let element = AnnotationElement(
                zIndex: nextZIndex,
                transform: ElementTransform(boundsInCanvasPixels: bounds),
                payload: .stepNumber(StepNumberStyle(number: nextStepNumber))
            )
            document.elements.append(element)
            selectOnly(element.id)
            // Step markers intentionally stay active for continuous placement.
            activeTool = .stepNumber
        }
    }

    func insertPixelate(in bounds: CanvasRect) {
        insertEffect(in: bounds, payload: .pixelate(PixelateStyle()), actionName: "Pixelierung hinzufügen")
    }

    func insertFocus(in bounds: CanvasRect) {
        insertEffect(in: bounds, payload: .focus(FocusStyle()), actionName: "Fokus hinzufügen")
    }

    private func insertEffect(in bounds: CanvasRect, payload: AnnotationPayload, actionName: String) {
        let clamped = bounds.clamped(to: document.original.pixelSize, minimumSize: 12)
        guard clamped.width >= 12, clamped.height >= 12 else { return }

        perform(actionName: actionName) {
            let element = AnnotationElement(
                zIndex: nextZIndex,
                transform: ElementTransform(boundsInCanvasPixels: clamped),
                payload: payload
            )
            document.elements.append(element)
            selectOnly(element.id)
            activeTool = .select
        }
    }

    func previewBounds(_ bounds: CanvasRect, for elementID: UUID) {
        guard let index = index(of: elementID) else { return }
        document.elements[index].transform.boundsInCanvasPixels = bounds.clamped(
            to: document.original.pixelSize,
            minimumSize: minimumBoundsSize(for: document.elements[index])
        )
    }

    func commitBoundsChange(
        for elementID: UUID,
        from originalBounds: CanvasRect,
        actionName: String
    ) {
        guard let index = index(of: elementID) else { return }
        let currentBounds = document.elements[index].transform.boundsInCanvasPixels
        guard currentBounds != originalBounds else { return }

        var previous = document
        previous.elements[index].transform.boundsInCanvasPixels = originalBounds
        registerChange(from: previous, to: document, actionName: actionName)
    }

    func previewArrowEndpoint(_ isStart: Bool, for elementID: UUID, at point: CGPoint) {
        guard let index = index(of: elementID),
              case var .arrow(style) = document.elements[index].payload
        else { return }

        let oldBounds = document.elements[index].transform.boundsInCanvasPixels
        let oldStart = style.startPoint.point(in: oldBounds)
        let oldEnd = style.endPoint.point(in: oldBounds)
        let geometry = arrowGeometry(
            start: isStart ? point : oldStart,
            end: isStart ? oldEnd : point
        )
        style.startPoint = geometry.start
        style.endPoint = geometry.end
        document.elements[index].transform.boundsInCanvasPixels = geometry.bounds
        document.elements[index].payload = .arrow(style)
    }

    func commitElementChange(
        for elementID: UUID,
        from originalElement: AnnotationElement,
        actionName: String
    ) {
        guard let index = index(of: elementID),
              document.elements[index] != originalElement
        else { return }
        var previous = document
        previous.elements[index] = originalElement
        registerChange(from: previous, to: document, actionName: actionName)
    }

    func deleteSelection() {
        let deletedIDs = selectedElementIDs
        guard !deletedIDs.isEmpty else { return }
        let deletedStepNumber = document.elements.contains { element in
            guard deletedIDs.contains(element.id) else { return false }
            if case .stepNumber = element.payload {
                return true
            }
            return false
        }

        perform(actionName: deletedIDs.count == 1 ? "Element löschen" : "Elemente löschen") {
            document.elements.removeAll { deletedIDs.contains($0.id) }
            clearSelection()
            normalizeZIndexes()
            if deletedStepNumber {
                normalizeStepNumbers()
            }
        }
    }

    func duplicateSelection() {
        let sourceElements = selectedElements.sorted { $0.zIndex < $1.zIndex }
        guard !sourceElements.isEmpty else { return }

        perform(actionName: sourceElements.count == 1 ? "Element duplizieren" : "Elemente duplizieren") {
            var nextNumber = nextStepNumber
            var duplicateIDs: Set<UUID> = []
            for source in sourceElements {
                let duplicate = duplicatedElement(
                    from: source,
                    zIndex: nextZIndex,
                    stepNumber: &nextNumber
                )
                document.elements.append(duplicate)
                duplicateIDs.insert(duplicate.id)
            }
            setSelection(duplicateIDs)
        }
    }

    func bringSelectionForward() {
        adjustSelectionZOrder(towardFront: true)
    }

    func sendSelectionBackward() {
        adjustSelectionZOrder(towardFront: false)
    }

    func setSelectedShapeStyle(_ style: ShapeStyle, actionName: String) {
        guard let selectedElementID, let index = index(of: selectedElementID) else { return }

        perform(actionName: actionName) {
            switch document.elements[index].payload {
            case .rectangle:
                document.elements[index].payload = .rectangle(style)
            case .ellipse:
                document.elements[index].payload = .ellipse(style)
            case .arrow:
                break
            case .redaction:
                break
            case .marker:
                break
            case .text:
                break
            case .speechBubble, .stepNumber:
                break
            case .pixelate, .focus: break
            }
        }
    }

    func setSelectedArrowStyle(_ style: ArrowStyle, actionName: String) {
        guard let selectedElementID, let index = index(of: selectedElementID),
              case .arrow = document.elements[index].payload
        else { return }
        perform(actionName: actionName) {
            document.elements[index].payload = .arrow(style)
        }
    }

    func setSelectedRedactionStyle(_ style: RedactionStyle, actionName: String) {
        guard let selectedElementID, let index = index(of: selectedElementID),
              case .redaction = document.elements[index].payload
        else { return }
        perform(actionName: actionName) {
            document.elements[index].payload = .redaction(style)
        }
    }

    func setSelectedMarkerStyle(_ style: MarkerStyle, actionName: String) {
        guard let selectedElementID, let index = index(of: selectedElementID),
              case .marker = document.elements[index].payload
        else { return }
        perform(actionName: actionName) {
            document.elements[index].payload = .marker(style)
        }
    }

    func setSelectedTextStyle(_ style: TextStyle, actionName: String) {
        guard let selectedElementID, let index = index(of: selectedElementID),
              case .text = document.elements[index].payload
        else { return }
        perform(actionName: actionName) {
            document.elements[index].payload = .text(style)
        }
    }

    func setSelectedSpeechBubbleStyle(_ style: SpeechBubbleStyle, actionName: String) {
        guard let selectedElementID, let index = index(of: selectedElementID), case .speechBubble = document.elements[index].payload else { return }
        perform(actionName: actionName) { document.elements[index].payload = .speechBubble(style) }
    }

    func setSelectedStepNumberStyle(_ style: StepNumberStyle, actionName: String) {
        guard let selectedElementID,
              let index = index(of: selectedElementID),
              case let .stepNumber(currentStyle) = document.elements[index].payload
        else { return }

        let requestedNumber = min(max(stepNumberStart, style.number), stepNumberRange.upperBound)
        perform(actionName: actionName) {
            var updated = style
            updated.number = requestedNumber
            document.elements[index].payload = .stepNumber(updated)

            if requestedNumber != currentStyle.number {
                placeStepNumber(
                    selectedElementID,
                    at: requestedNumber - stepNumberStart + 1
                )
            }
        }
    }

    func setSelectedStepNumberShape(
        _ shape: StepNumberShape,
        actionName: String = "Schrittform ändern"
    ) {
        guard selectedStepNumberStyles != nil else { return }
        perform(actionName: actionName) {
            for index in document.elements.indices where selectedElementIDs.contains(document.elements[index].id) {
                guard case var .stepNumber(style) = document.elements[index].payload else { continue }
                style.shape = shape
                document.elements[index].payload = .stepNumber(style)
            }
        }
    }

    func setSelectedPixelateStyle(_ style: PixelateStyle, actionName: String) {
        guard let selectedElementID,
              let index = index(of: selectedElementID),
              case .pixelate = document.elements[index].payload
        else { return }
        perform(actionName: actionName) {
            document.elements[index].payload = .pixelate(style)
        }
    }

    func setSelectedFocusStyle(_ style: FocusStyle, actionName: String) {
        guard let selectedElementID,
              let index = index(of: selectedElementID),
              case .focus = document.elements[index].payload
        else { return }
        perform(actionName: actionName) {
            document.elements[index].payload = .focus(style)
        }
    }

    func copySelection() {
        let elements = selectedElements.sorted { $0.zIndex < $1.zIndex }
        guard !elements.isEmpty,
              let data = try? JSONEncoder().encode(elements)
        else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .r3dshotAnnotations)

        // Retain compatibility with existing single-element clipboard data.
        if elements.count == 1,
           let legacyData = try? JSONEncoder().encode(elements[0]) {
            pasteboard.setData(legacyData, forType: .r3dshotAnnotation)
        }
    }

    func paste() {
        guard let sourceElements = pasteboardElements(), !sourceElements.isEmpty else { return }

        perform(actionName: sourceElements.count == 1 ? "Element einsetzen" : "Elemente einsetzen") {
            var nextNumber = nextStepNumber
            var pastedIDs: Set<UUID> = []
            for source in sourceElements.sorted(by: { $0.zIndex < $1.zIndex }) {
                let pasted = duplicatedElement(
                    from: source,
                    zIndex: nextZIndex,
                    stepNumber: &nextNumber
                )
                document.elements.append(pasted)
                pastedIDs.insert(pasted.id)
            }
            setSelection(pastedIDs)
        }
    }

    private var nextZIndex: Int {
        (document.elements.map(\.zIndex).max() ?? -1) + 1
    }

    private func validSelection(from elementIDs: Set<UUID>) -> Set<UUID> {
        let validIDs = Set(document.elements.map(\.id))
        return elementIDs.intersection(validIDs)
    }

    private func elementID(at point: CGPoint, tolerance: CGFloat) -> UUID? {
        document.elements
            .sorted { $0.zIndex > $1.zIndex }
            .first { hitTest($0, at: point, tolerance: tolerance) }?
            .id
    }

    private func validMoveEntries(
        from originalBounds: [UUID: CanvasRect]
    ) -> [(id: UUID, bounds: CanvasRect)] {
        originalBounds.compactMap { id, bounds in
            guard selectedElementIDs.contains(id), index(of: id) != nil else { return nil }
            return (id, bounds)
        }
    }

    private func clampedSelectionTranslation(
        _ proposed: CGSize,
        for bounds: [CanvasRect]
    ) -> CGSize {
        guard let minX = bounds.map(\.x).min(),
              let maxX = bounds.map({ $0.x + $0.width }).max(),
              let minY = bounds.map(\.y).min(),
              let maxY = bounds.map({ $0.y + $0.height }).max()
        else { return .zero }

        let canvas = document.original.pixelSize.cgSize
        return CGSize(
            width: min(max(proposed.width, -minX), canvas.width - maxX),
            height: min(max(proposed.height, -minY), canvas.height - maxY)
        )
    }

    private func duplicatedElement(
        from source: AnnotationElement,
        zIndex: Int,
        stepNumber: inout Int
    ) -> AnnotationElement {
        var payload = source.payload
        if case var .stepNumber(style) = payload {
            style.number = stepNumber
            stepNumber += 1
            payload = .stepNumber(style)
        }

        var duplicate = AnnotationElement(
            zIndex: zIndex,
            transform: source.transform,
            payload: payload
        )
        duplicate.transform.boundsInCanvasPixels = CanvasRect(
            duplicate.transform.boundsInCanvasPixels.cgRect.offsetBy(dx: 16, dy: 16)
        )
        .clamped(
            to: document.original.pixelSize,
            minimumSize: minimumBoundsSize(for: source)
        )
        return duplicate
    }

    private func pasteboardElements() -> [AnnotationElement]? {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .r3dshotAnnotations),
           let elements = try? JSONDecoder().decode([AnnotationElement].self, from: data) {
            return elements
        }
        if let data = pasteboard.data(forType: .r3dshotAnnotation),
           let element = try? JSONDecoder().decode(AnnotationElement.self, from: data) {
            return [element]
        }
        return nil
    }

    private func adjustSelectionZOrder(towardFront: Bool) {
        guard hasSelection else { return }

        perform(actionName: towardFront ? "Nach vorne" : "Nach hinten") {
            var orderedIDs = document.elements
                .sorted { $0.zIndex < $1.zIndex }
                .map(\.id)

            if towardFront {
                for position in orderedIDs.indices.reversed() {
                    let next = position + 1
                    guard next < orderedIDs.count,
                          selectedElementIDs.contains(orderedIDs[position]),
                          !selectedElementIDs.contains(orderedIDs[next])
                    else { continue }
                    orderedIDs.swapAt(position, next)
                }
            } else {
                for position in orderedIDs.indices {
                    let previous = position - 1
                    guard previous >= 0,
                          selectedElementIDs.contains(orderedIDs[position]),
                          !selectedElementIDs.contains(orderedIDs[previous])
                    else { continue }
                    orderedIDs.swapAt(position, previous)
                }
            }

            for (zIndex, id) in orderedIDs.enumerated() {
                guard let index = index(of: id) else { continue }
                document.elements[index].zIndex = zIndex
            }
        }
    }

    private func minimumBoundsSize(for element: AnnotationElement) -> CGFloat {
        switch element.payload {
        case .text, .pixelate, .focus:
            12
        case .speechBubble, .stepNumber:
            24
        case .rectangle, .ellipse, .arrow, .redaction, .marker:
            4
        }
    }

    private func hitTest(
        _ element: AnnotationElement,
        at point: CGPoint,
        tolerance: CGFloat
    ) -> Bool {
        switch element.payload {
        case .rectangle, .ellipse, .redaction, .text, .speechBubble, .stepNumber, .pixelate, .focus:
            return element.transform.boundsInCanvasPixels.cgRect
                .insetBy(dx: -tolerance, dy: -tolerance)
                .contains(point)
        case let .arrow(style):
            return distance(
                from: point,
                toSegmentFrom: style.startPoint.point(in: element.transform.boundsInCanvasPixels),
                to: style.endPoint.point(in: element.transform.boundsInCanvasPixels)
            ) <= max(tolerance, style.lineWidth / 2 + tolerance)
        case let .marker(style):
            let points = style.points.map {
                $0.point(in: element.transform.boundsInCanvasPixels)
            }
            guard let first = points.first else { return false }
            if points.count == 1 {
                return hypot(point.x - first.x, point.y - first.y) <= style.lineWidth / 2 + tolerance
            }
            return zip(points, points.dropFirst()).contains { start, end in
                distance(from: point, toSegmentFrom: start, to: end)
                    <= style.lineWidth / 2 + tolerance
            }
        }
    }

    private func distance(from point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - start.x, point.y - start.y) }
        let projection = min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        return hypot(point.x - (start.x + projection * dx), point.y - (start.y + projection * dy))
    }

    private func arrowGeometry(
        start: CGPoint,
        end: CGPoint
    ) -> (bounds: CanvasRect, start: NormalizedPoint, end: NormalizedPoint) {
        let minimumSize: CGFloat = 4
        let width = max(minimumSize, abs(end.x - start.x))
        let height = max(minimumSize, abs(end.y - start.y))
        let rawBounds = CanvasRect(
            x: min(start.x, end.x) - max(0, minimumSize - abs(end.x - start.x)) / 2,
            y: min(start.y, end.y) - max(0, minimumSize - abs(end.y - start.y)) / 2,
            width: width,
            height: height
        )
        let bounds = rawBounds.clamped(to: document.original.pixelSize, minimumSize: minimumSize)
        func normalized(_ point: CGPoint) -> NormalizedPoint {
            NormalizedPoint(
                x: min(1, max(0, (point.x - bounds.x) / bounds.width)),
                y: min(1, max(0, (point.y - bounds.y) / bounds.height))
            )
        }
        return (bounds, normalized(start), normalized(end))
    }

    private func index(of id: UUID) -> Int? {
        document.elements.firstIndex { $0.id == id }
    }

    private func normalizeZIndexes() {
        let orderedIDs = document.elements
            .sorted { $0.zIndex < $1.zIndex }
            .map(\.id)
        for (zIndex, id) in orderedIDs.enumerated() {
            if let index = index(of: id) {
                document.elements[index].zIndex = zIndex
            }
        }
    }

    private func placeStepNumber(_ id: UUID, at position: Int) {
        var orderedIDs = stepNumberIndices()
            .map { document.elements[$0].id }
        orderedIDs.removeAll { $0 == id }
        orderedIDs.insert(id, at: min(max(0, position - 1), orderedIDs.count))

        for (number, stepID) in orderedIDs.enumerated() {
            guard let index = index(of: stepID),
                  case var .stepNumber(style) = document.elements[index].payload
            else { continue }
            style.number = stepNumberStart + number
            document.elements[index].payload = .stepNumber(style)
        }
    }

    private func normalizeStepNumbers() {
        for (number, index) in stepNumberIndices().enumerated() {
            guard case var .stepNumber(style) = document.elements[index].payload else { continue }
            style.number = stepNumberStart + number
            document.elements[index].payload = .stepNumber(style)
        }
    }

    private func stepNumberIndices() -> [Int] {
        document.elements.indices
            .filter {
                if case .stepNumber = document.elements[$0].payload {
                    return true
                }
                return false
            }
            .sorted { lhs, rhs in
                guard case let .stepNumber(lhsStyle) = document.elements[lhs].payload,
                      case let .stepNumber(rhsStyle) = document.elements[rhs].payload
                else { return lhs < rhs }
                if lhsStyle.number != rhsStyle.number {
                    return lhsStyle.number < rhsStyle.number
                }
                return lhs < rhs
            }
    }

    private func perform(actionName: String, mutation: () -> Void) {
        let previous = document
        mutation()
        guard previous != document else { return }
        registerChange(from: previous, to: document, actionName: actionName)
    }

    private func registerChange(
        from previous: ScreenshotDocument,
        to current: ScreenshotDocument,
        actionName: String,
        previousStepNumberStart: Int? = nil,
        currentStepNumberStart: Int? = nil
    ) {
        let previousStart = previousStepNumberStart ?? stepNumberStart
        let currentStart = currentStepNumberStart ?? stepNumberStart
        undoManager.registerUndo(withTarget: self) { store in
            store.restore(
                previous,
                replacing: current,
                actionName: actionName,
                stepNumberStart: previousStart,
                replacingStepNumberStart: currentStart
            )
        }
        undoManager.setActionName(actionName)
    }

    private func restore(
        _ value: ScreenshotDocument,
        replacing previous: ScreenshotDocument,
        actionName: String,
        stepNumberStart: Int,
        replacingStepNumberStart: Int
    ) {
        document = value
        self.stepNumberStart = stepNumberStart
        selectedElementIDs = validSelection(from: selectedElementIDs)
        registerChange(
            from: previous,
            to: value,
            actionName: actionName,
            previousStepNumberStart: replacingStepNumberStart,
            currentStepNumberStart: stepNumberStart
        )
    }
}

private extension NSPasteboard.PasteboardType {
    static let r3dshotAnnotation = NSPasteboard.PasteboardType(
        "org.r3d.R3Dshot.annotation-element"
    )
    static let r3dshotAnnotations = NSPasteboard.PasteboardType(
        "org.r3d.R3Dshot.annotation-elements"
    )
}
