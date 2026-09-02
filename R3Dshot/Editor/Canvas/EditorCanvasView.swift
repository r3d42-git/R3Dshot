import AppKit
import SwiftUI

struct EditorCanvasView: View {
    @Bindable var store: EditorStore

    @State private var interaction: CanvasInteraction?
    @State private var draftBounds: CanvasRect?
    @State private var draftEndPoint: CGPoint?
    @State private var draftMarkerPoints: [CGPoint] = []
    @State private var markerDrawingMode: MarkerDrawingMode = .undecided

    var body: some View {
        GeometryReader { geometry in
            let isCropping = store.activeTool == .crop
            let previewDocument = displayDocument(isCropping: isCropping)
            let previewImage = try? ScreenshotRenderer.render(
                document: previewDocument,
                originalImage: store.session.originalImage
            )
            let crop = previewDocument.crop.boundsInCanvasPixels
            let canvasSize = PixelSize(
                width: max(1, Int(crop.width.rounded())),
                height: max(1, Int(crop.height.rounded()))
            )
            let availableWidth = max(80, geometry.size.width - 64)
            let availableHeight = max(80, geometry.size.height - 64)
            let fittedScale = min(
                availableWidth / max(1, canvasSize.cgSize.width),
                availableHeight / max(1, canvasSize.cgSize.height)
            )
            let scale = max(0.01, fittedScale * store.zoom)
            let transform = CanvasTransform(
                canvasSize: canvasSize,
                scale: scale,
                canvasOrigin: CGPoint(x: crop.x, y: crop.y)
            )
            let surfaceSize = CGSize(
                width: canvasSize.cgSize.width * scale,
                height: canvasSize.cgSize.height * scale
            )

            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    Color.clear
                    editorSurface(
                        size: surfaceSize,
                        previewImage: previewImage,
                        transform: transform,
                        showsCropControls: isCropping
                    )
                }
                .frame(
                    width: max(geometry.size.width, surfaceSize.width + 64),
                    height: max(geometry.size.height, surfaceSize.height + 64)
                )
            }
            .scrollIndicators(.automatic)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))
        }
    }

    private func editorSurface(
        size: CGSize,
        previewImage: CGImage?,
        transform: CanvasTransform,
        showsCropControls: Bool
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if let previewImage {
                Image(nsImage: NSImage(cgImage: previewImage, size: .zero))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size.width, height: size.height)
            }

            if let interaction,
               case .createMarker = interaction.mode,
               draftMarkerPoints.count > 1 {
                markerDraftPath(points: draftMarkerPoints, scale: transform.scale)
                    .stroke(
                        Color(red: 1, green: 0.84, blue: 0.12).opacity(0.38),
                        style: StrokeStyle(lineWidth: 20 * transform.scale, lineCap: .round, lineJoin: .round)
                    )
                    .allowsHitTesting(false)
            } else if let interaction,
               case .createArrow = interaction.mode,
               let draftEndPoint {
                let start = CGPoint(
                    x: interaction.startPoint.x * transform.scale,
                    y: interaction.startPoint.y * transform.scale
                )
                let end = CGPoint(
                    x: draftEndPoint.x * transform.scale,
                    y: draftEndPoint.y * transform.scale
                )
                arrowDraftPath(from: start, to: end)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .allowsHitTesting(false)
            } else if let draftBounds {
                let rect = transform.viewRect(from: draftBounds)
                Group {
                    if store.activeTool == .redaction {
                        Rectangle()
                            .fill(.black.opacity(0.72))
                            .overlay {
                                Rectangle()
                                    .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                            }
                    } else if store.activeTool == .ellipse {
                        Ellipse()
                            .stroke(.tint, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(.tint, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)
            }

            if showsCropControls {
                CropSelectionHandles(store: store, transform: transform)
            } else if let selectedElement = store.selectedElement {
                SelectionHandles(
                    store: store,
                    element: selectedElement,
                    transform: transform
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .coordinateSpace(name: CanvasCoordinateSpace.name)
        .gesture(surfaceGesture(transform: transform))
        .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
        .accessibilityLabel("Screenshot-Arbeitsfläche")
    }

    private func displayDocument(isCropping: Bool) -> ScreenshotDocument {
        guard isCropping else { return store.document }
        var document = store.document
        document.crop = .fullImage(document.original.pixelSize)
        return document
    }

    private func surfaceGesture(transform: CanvasTransform) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(CanvasCoordinateSpace.name))
            .onChanged { value in
                let point = transform.canvasPoint(from: value.location)

                if interaction == nil {
                    beginInteraction(at: point, transform: transform)
                }

                guard let interaction else { return }
                switch interaction.mode {
                case .createRectangle, .createEllipse, .createRedaction, .createCrop, .createText:
                    draftBounds = CanvasRect(
                        CGRect(
                            x: interaction.startPoint.x,
                            y: interaction.startPoint.y,
                            width: point.x - interaction.startPoint.x,
                            height: point.y - interaction.startPoint.y
                        )
                    )
                    .clamped(to: store.document.original.pixelSize)
                case .createArrow:
                    draftEndPoint = point
                case .createMarker:
                    let dx = point.x - interaction.startPoint.x
                    let dy = point.y - interaction.startPoint.y
                    if markerDrawingMode == .undecided {
                        if abs(dx) >= 16 {
                            markerDrawingMode = abs(dy) <= abs(dx) * 0.25
                                ? .horizontal
                                : .freehand
                            if markerDrawingMode == .horizontal {
                                draftMarkerPoints = draftMarkerPoints.map {
                                    CGPoint(x: $0.x, y: interaction.startPoint.y)
                                }
                            }
                        } else if abs(dy) >= 16 {
                            markerDrawingMode = .freehand
                        }
                    }
                    let constrainedPoint = markerDrawingMode == .horizontal
                        ? CGPoint(x: point.x, y: interaction.startPoint.y)
                        : point
                    if let last = draftMarkerPoints.last,
                       hypot(constrainedPoint.x - last.x, constrainedPoint.y - last.y) >= 0.75 {
                        draftMarkerPoints.append(constrainedPoint)
                    }

                case .move:
                    guard let elementID = interaction.elementID,
                          let originalBounds = interaction.originalBounds
                    else { return }
                    let dx = point.x - interaction.startPoint.x
                    let dy = point.y - interaction.startPoint.y
                    store.previewBounds(
                        movedBounds(originalBounds, dx: dx, dy: dy),
                        for: elementID
                    )
                case .idle:
                    break
                }
            }
            .onEnded { _ in
                guard let interaction else { return }
                switch interaction.mode {
                case .createRectangle:
                    if let draftBounds, draftBounds.width >= 4, draftBounds.height >= 4 {
                        store.insertRectangle(in: draftBounds)
                    }
                case .createRedaction:
                    if let draftBounds, draftBounds.width >= 4, draftBounds.height >= 4 {
                        store.insertRedaction(in: draftBounds)
                    }
                case .createEllipse:
                    if let draftBounds, draftBounds.width >= 4, draftBounds.height >= 4 {
                        store.insertEllipse(in: draftBounds)
                    }
                case .createArrow:
                    if let draftEndPoint {
                        store.insertArrow(from: interaction.startPoint, to: draftEndPoint)
                    }
                case .createMarker:
                    store.insertMarker(points: draftMarkerPoints)
                case .createCrop:
                    if let draftBounds, draftBounds.width >= 4, draftBounds.height >= 4 {
                        store.setCrop(draftBounds)
                    }
                case .createText:
                    if let draftBounds, draftBounds.width >= 12, draftBounds.height >= 12 {
                        store.insertText(in: draftBounds)
                    }
                case .move:
                    if let elementID = interaction.elementID,
                       let originalBounds = interaction.originalBounds {
                        store.commitBoundsChange(
                            for: elementID,
                            from: originalBounds,
                            actionName: "Element verschieben"
                        )
                    }
                case .idle:
                    break
                }
                self.interaction = nil
                draftBounds = nil
                draftEndPoint = nil
                draftMarkerPoints = []
                markerDrawingMode = .undecided
            }
    }

    private func beginInteraction(at point: CGPoint, transform: CanvasTransform) {
        switch store.activeTool {
        case .rectangle:
            interaction = CanvasInteraction(
                mode: .createRectangle,
                startPoint: point,
                elementID: nil,
                originalBounds: nil
            )
        case .ellipse:
            interaction = CanvasInteraction(
                mode: .createEllipse,
                startPoint: point,
                elementID: nil,
                originalBounds: nil
            )
        case .arrow:
            interaction = CanvasInteraction(
                mode: .createArrow,
                startPoint: point,
                elementID: nil,
                originalBounds: nil
            )
        case .redaction:
            interaction = CanvasInteraction(
                mode: .createRedaction,
                startPoint: point,
                elementID: nil,
                originalBounds: nil
            )
        case .marker:
            draftMarkerPoints = [point]
            markerDrawingMode = .undecided
            interaction = CanvasInteraction(
                mode: .createMarker,
                startPoint: point,
                elementID: nil,
                originalBounds: nil
            )
        case .crop:
            interaction = CanvasInteraction(
                mode: .createCrop,
                startPoint: point,
                elementID: nil,
                originalBounds: nil
            )
        case .text:
            interaction = CanvasInteraction(
                mode: .createText,
                startPoint: point,
                elementID: nil,
                originalBounds: nil
            )
        case .select:
            store.selectElement(at: point, tolerance: 6 / transform.scale)
            guard let selectedElement = store.selectedElement else {
                interaction = CanvasInteraction(
                    mode: .idle,
                    startPoint: point,
                    elementID: nil,
                    originalBounds: nil
                )
                return
            }
            interaction = CanvasInteraction(
                mode: .move,
                startPoint: point,
                elementID: selectedElement.id,
                originalBounds: selectedElement.transform.boundsInCanvasPixels
            )
        }
    }

    private func movedBounds(_ original: CanvasRect, dx: CGFloat, dy: CGFloat) -> CanvasRect {
        let size = store.document.original.pixelSize.cgSize
        return CanvasRect(
            x: min(max(0, original.x + dx), max(0, size.width - original.width)),
            y: min(max(0, original.y + dy), max(0, size.height - original.height)),
            width: original.width,
            height: original.height
        )
    }

    private func arrowDraftPath(from start: CGPoint, to end: CGPoint) -> Path {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headAngle = CGFloat.pi / 7
        let headLength: CGFloat = 14
        let left = CGPoint(
            x: end.x - cos(angle - headAngle) * headLength,
            y: end.y - sin(angle - headAngle) * headLength
        )
        let right = CGPoint(
            x: end.x - cos(angle + headAngle) * headLength,
            y: end.y - sin(angle + headAngle) * headLength
        )
        return Path { path in
            path.move(to: start)
            path.addLine(to: end)
            path.move(to: left)
            path.addLine(to: end)
            path.addLine(to: right)
        }
    }

    private func markerDraftPath(points: [CGPoint], scale: CGFloat) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * scale, y: point.y * scale))
            }
        }
    }
}

private struct CanvasInteraction {
    enum Mode {
        case createRectangle
        case createEllipse
        case createArrow
        case createRedaction
        case createMarker
        case createCrop
        case createText
        case move
        case idle
    }

    let mode: Mode
    let startPoint: CGPoint
    let elementID: UUID?
    let originalBounds: CanvasRect?
}

private enum CanvasCoordinateSpace {
    static let name = "R3DshotEditorCanvas"
}

private enum MarkerDrawingMode {
    case undecided
    case horizontal
    case freehand
}

private struct CropSelectionHandles: View {
    let store: EditorStore
    let transform: CanvasTransform

    var body: some View {
        let rect = transform.viewRect(from: store.cropBounds)

        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [7, 4]))
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)

            ForEach(ResizeCorner.allCases) { corner in
                CropResizeHandle(
                    store: store,
                    corner: corner,
                    transform: transform
                )
                .position(corner.position(in: rect))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zuschnitt anpassen")
    }
}

private struct CropResizeHandle: View {
    let store: EditorStore
    let corner: ResizeCorner
    let transform: CanvasTransform

    @State private var originalCrop: CropState?

    var body: some View {
        Circle()
            .fill(.background)
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: 12, height: 12)
            .contentShape(Rectangle().inset(by: -6))
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        if originalCrop == nil {
                            originalCrop = store.document.crop
                        }
                        guard let originalCrop else { return }
                        store.previewCrop(
                            corner.resized(
                                originalCrop.boundsInCanvasPixels,
                                to: transform.canvasPoint(from: value.location)
                            )
                        )
                    }
                    .onEnded { _ in
                        if let originalCrop {
                            store.commitCropChange(
                                from: originalCrop,
                                actionName: "Zuschnitt anpassen"
                            )
                        }
                        originalCrop = nil
                    }
            )
            .help("Zuschnitt skalieren")
    }
}

private struct SelectionHandles: View {
    let store: EditorStore
    let element: AnnotationElement
    let transform: CanvasTransform

    var body: some View {
        let rect = transform.viewRect(from: element.transform.boundsInCanvasPixels)

        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 1.5)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)

            if case let .arrow(style) = element.payload {
                ArrowEndpointHandle(
                    store: store,
                    element: element,
                    isStart: true,
                    transform: transform
                )
                .position(style.startPoint.viewPoint(in: rect))
                ArrowEndpointHandle(
                    store: store,
                    element: element,
                    isStart: false,
                    transform: transform
                )
                .position(style.endPoint.viewPoint(in: rect))
            } else {
                ForEach(ResizeCorner.allCases) { corner in
                    ResizeHandle(
                        store: store,
                        elementID: element.id,
                        corner: corner,
                        transform: transform
                    )
                    .position(corner.position(in: rect))
                }
            }
        }
    }
}

private struct ArrowEndpointHandle: View {
    let store: EditorStore
    let element: AnnotationElement
    let isStart: Bool
    let transform: CanvasTransform

    @State private var originalElement: AnnotationElement?

    var body: some View {
        Circle()
            .fill(.background)
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: 11, height: 11)
            .contentShape(Rectangle().inset(by: -6))
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        if originalElement == nil {
                            originalElement = store.document.elements
                                .first(where: { $0.id == element.id })
                        }
                        store.previewArrowEndpoint(
                            isStart,
                            for: element.id,
                            at: transform.canvasPoint(from: value.location)
                        )
                    }
                    .onEnded { _ in
                        if let originalElement {
                            store.commitElementChange(
                                for: element.id,
                                from: originalElement,
                                actionName: "Pfeilendpunkt verschieben"
                            )
                        }
                        originalElement = nil
                    }
            )
            .help(isStart ? "Pfeilanfang verschieben" : "Pfeilspitze verschieben")
    }
}

private extension NormalizedPoint {
    func viewPoint(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
}

private struct ResizeHandle: View {
    let store: EditorStore
    let elementID: UUID
    let corner: ResizeCorner
    let transform: CanvasTransform

    @State private var originalBounds: CanvasRect?

    var body: some View {
        Circle()
            .fill(.background)
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: 11, height: 11)
            .contentShape(Rectangle().inset(by: -6))
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        if originalBounds == nil {
                            originalBounds = store.document.elements
                                .first(where: { $0.id == elementID })?
                                .transform.boundsInCanvasPixels
                        }
                        guard let originalBounds else { return }
                        let point = transform.canvasPoint(from: value.location)
                        store.previewBounds(
                            corner.resized(originalBounds, to: point),
                            for: elementID
                        )
                    }
                    .onEnded { _ in
                        if let originalBounds {
                            store.commitBoundsChange(
                                for: elementID,
                                from: originalBounds,
                                actionName: "Element skalieren"
                            )
                        }
                        originalBounds = nil
                    }
            )
            .help("Skalieren")
    }
}

private enum ResizeCorner: CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: Self { self }

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    func resized(_ original: CanvasRect, to point: CGPoint) -> CanvasRect {
        let minSize: CGFloat = 4
        let rect = original.cgRect
        switch self {
        case .topLeft:
            return CanvasRect(
                x: min(point.x, rect.maxX - minSize),
                y: min(point.y, rect.maxY - minSize),
                width: rect.maxX - min(point.x, rect.maxX - minSize),
                height: rect.maxY - min(point.y, rect.maxY - minSize)
            )
        case .topRight:
            return CanvasRect(
                x: rect.minX,
                y: min(point.y, rect.maxY - minSize),
                width: max(minSize, point.x - rect.minX),
                height: rect.maxY - min(point.y, rect.maxY - minSize)
            )
        case .bottomLeft:
            return CanvasRect(
                x: min(point.x, rect.maxX - minSize),
                y: rect.minY,
                width: rect.maxX - min(point.x, rect.maxX - minSize),
                height: max(minSize, point.y - rect.minY)
            )
        case .bottomRight:
            return CanvasRect(
                x: rect.minX,
                y: rect.minY,
                width: max(minSize, point.x - rect.minX),
                height: max(minSize, point.y - rect.minY)
            )
        }
    }
}
