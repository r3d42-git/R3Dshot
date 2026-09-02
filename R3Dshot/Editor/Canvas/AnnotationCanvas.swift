import SwiftUI

struct AnnotationCanvas: View {
    let document: ScreenshotDocument

    var body: some View {
        Canvas { graphicsContext, size in
            let scaleX = size.width / max(1, document.original.pixelSize.cgSize.width)
            let scaleY = size.height / max(1, document.original.pixelSize.cgSize.height)

            graphicsContext.withCGContext { context in
                context.scaleBy(x: scaleX, y: scaleY)
                ScreenshotRenderer.drawAnnotations(
                    document.elements,
                    in: context,
                    canvasHeight: document.original.pixelSize.cgSize.height,
                    coordinateOrigin: .topLeft
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
