import AppKit
import Observation

enum EditorTool: String, CaseIterable, Identifiable {
    case select
    case rectangle
    case ellipse
    case arrow
    case redaction
    case marker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Auswahl"
        case .rectangle: "Rechteck"
        case .ellipse: "Ellipse"
        case .arrow: "Pfeil"
        case .redaction: "Schwärzen"
        case .marker: "Marker"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "arrow.up.left"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .arrow: "arrow.up.right"
        case .redaction: "rectangle.fill"
        case .marker: "highlighter"
        }
    }

    var helpText: String {
        switch self {
        case .select: "Auswahlwerkzeug – Elemente auswählen, verschieben und skalieren"
        case .rectangle: "Rechteckwerkzeug – ein Rechteck aufziehen"
        case .ellipse: "Ellipsenwerkzeug – eine Ellipse aufziehen"
        case .arrow: "Pfeilwerkzeug – vom Startpunkt zur Pfeilspitze ziehen"
        case .redaction: "Schwärzen – einen Bereich vollständig und dauerhaft sichtbar abdecken"
        case .marker: "Marker – einen Bereich freihändig transparent hervorheben"
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
    let session: EditorSession
    private(set) var document: ScreenshotDocument
    var selectedElementID: UUID?
    var activeTool: EditorTool = .select
    var zoom: CGFloat = 1
    var isInspectorPresented = true
    private(set) var savedURL: URL?

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

    var selectedElement: AnnotationElement? {
        guard let selectedElementID else { return nil }
        return document.elements.first { $0.id == selectedElementID }
    }

    var selectedShapeStyle: ShapeStyle? {
        switch selectedElement?.payload {
        case let .rectangle(style), let .ellipse(style): style
        case .arrow, .redaction, .marker, nil: nil
        }
    }

    var selectedShapeTitle: String? {
        switch selectedElement?.payload {
        case .rectangle: "Rechteck"
        case .ellipse: "Ellipse"
        case .arrow: "Pfeil"
        case .redaction: "Schwärzung"
        case .marker: "Marker"
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

    var hasUnsavedChanges: Bool {
        lastSavedDocument != document
    }

    func markSaved(at url: URL) {
        savedURL = url
        lastSavedDocument = document
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
            selectedElementID = element.id
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
            selectedElementID = element.id
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
            selectedElementID = element.id
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
            selectedElementID = element.id
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
            selectedElementID = element.id
            activeTool = .select
        }
    }

    func selectElement(at point: CGPoint, tolerance: CGFloat = 5) {
        selectedElementID = document.elements
            .sorted { $0.zIndex > $1.zIndex }
            .first { hitTest($0, at: point, tolerance: tolerance) }?
            .id
    }

    func previewBounds(_ bounds: CanvasRect, for elementID: UUID) {
        guard let index = index(of: elementID) else { return }
        document.elements[index].transform.boundsInCanvasPixels = bounds.clamped(
            to: document.original.pixelSize,
            minimumSize: 4
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
        guard let selectedElementID, let index = index(of: selectedElementID) else { return }
        perform(actionName: "Element löschen") {
            document.elements.remove(at: index)
            self.selectedElementID = nil
            normalizeZIndexes()
        }
    }

    func duplicateSelection() {
        guard let selectedElement else { return }
        perform(actionName: "Element duplizieren") {
            var duplicate = AnnotationElement(
                zIndex: nextZIndex,
                transform: selectedElement.transform,
                payload: selectedElement.payload
            )
            let shifted = duplicate.transform.boundsInCanvasPixels.cgRect.offsetBy(dx: 16, dy: 16)
            duplicate.transform.boundsInCanvasPixels = CanvasRect(shifted)
                .clamped(to: document.original.pixelSize, minimumSize: 4)
            document.elements.append(duplicate)
            selectedElementID = duplicate.id
        }
    }

    func bringSelectionForward() {
        guard let selectedElementID, let index = index(of: selectedElementID) else { return }
        let sorted = document.elements.indices.sorted {
            document.elements[$0].zIndex < document.elements[$1].zIndex
        }
        guard let position = sorted.firstIndex(of: index), position < sorted.count - 1 else { return }
        let otherIndex = sorted[position + 1]

        perform(actionName: "Nach vorne") {
            let selectedZIndex = document.elements[index].zIndex
            document.elements[index].zIndex = document.elements[otherIndex].zIndex
            document.elements[otherIndex].zIndex = selectedZIndex
        }
    }

    func sendSelectionBackward() {
        guard let selectedElementID, let index = index(of: selectedElementID) else { return }
        let sorted = document.elements.indices.sorted {
            document.elements[$0].zIndex < document.elements[$1].zIndex
        }
        guard let position = sorted.firstIndex(of: index), position > 0 else { return }
        let otherIndex = sorted[position - 1]

        perform(actionName: "Nach hinten") {
            let selectedZIndex = document.elements[index].zIndex
            document.elements[index].zIndex = document.elements[otherIndex].zIndex
            document.elements[otherIndex].zIndex = selectedZIndex
        }
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

    func copySelection() {
        guard let selectedElement,
              let data = try? JSONEncoder().encode(selectedElement)
        else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .r3dshotAnnotation)
    }

    func paste() {
        guard let data = NSPasteboard.general.data(forType: .r3dshotAnnotation),
              let element = try? JSONDecoder().decode(AnnotationElement.self, from: data)
        else { return }

        perform(actionName: "Element einsetzen") {
            var pasted = AnnotationElement(
                zIndex: nextZIndex,
                transform: element.transform,
                payload: element.payload
            )
            pasted.transform.boundsInCanvasPixels = CanvasRect(
                pasted.transform.boundsInCanvasPixels.cgRect.offsetBy(dx: 16, dy: 16)
            )
            .clamped(to: document.original.pixelSize, minimumSize: 4)
            document.elements.append(pasted)
            selectedElementID = pasted.id
        }
    }

    private var nextZIndex: Int {
        (document.elements.map(\.zIndex).max() ?? -1) + 1
    }

    private func hitTest(
        _ element: AnnotationElement,
        at point: CGPoint,
        tolerance: CGFloat
    ) -> Bool {
        switch element.payload {
        case .rectangle, .ellipse, .redaction:
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

    private func perform(actionName: String, mutation: () -> Void) {
        let previous = document
        mutation()
        guard previous != document else { return }
        registerChange(from: previous, to: document, actionName: actionName)
    }

    private func registerChange(
        from previous: ScreenshotDocument,
        to current: ScreenshotDocument,
        actionName: String
    ) {
        undoManager.registerUndo(withTarget: self) { store in
            store.restore(previous, replacing: current, actionName: actionName)
        }
        undoManager.setActionName(actionName)
    }

    private func restore(
        _ value: ScreenshotDocument,
        replacing previous: ScreenshotDocument,
        actionName: String
    ) {
        document = value
        if let selectedElementID,
           !document.elements.contains(where: { $0.id == selectedElementID }) {
            self.selectedElementID = nil
        }
        registerChange(from: previous, to: value, actionName: actionName)
    }
}

private extension NSPasteboard.PasteboardType {
    static let r3dshotAnnotation = NSPasteboard.PasteboardType(
        "org.r3d.R3Dshot.annotation-element"
    )
}
