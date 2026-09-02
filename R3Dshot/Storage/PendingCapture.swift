import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class PendingCapture: Identifiable {
    let id: UUID
    let image: CGImage
    let capturedAt: Date
    let source: CaptureSource

    init(
        id: UUID = UUID(),
        image: CGImage,
        capturedAt: Date,
        source: CaptureSource
    ) {
        self.id = id
        self.image = image
        self.capturedAt = capturedAt
        self.source = source
    }

    var pixelSizeDescription: String {
        "\(image.width) × \(image.height) px"
    }
}

@MainActor
@Observable
final class PendingCaptureStore {
    private(set) var captures: [PendingCapture] = []

    func insert(_ screenshot: CapturedScreenshot) -> PendingCapture {
        let capture = PendingCapture(
            id: screenshot.id,
            image: screenshot.image,
            capturedAt: screenshot.capturedAt,
            source: screenshot.source
        )
        captures.insert(capture, at: 0)
        return capture
    }

    func remove(_ capture: PendingCapture) {
        captures.removeAll { $0.id == capture.id }
    }
}
