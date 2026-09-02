import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class ScreenshotFileStore {
    enum StorageError: LocalizedError {
        case couldNotCreateImageDestination
        case couldNotEncodePNG

        var errorDescription: String? {
            switch self {
            case .couldNotCreateImageDestination:
                "PNG-Zieldatei konnte nicht erstellt werden."
            case .couldNotEncodePNG:
                "Screenshot konnte nicht als PNG geschrieben werden."
            }
        }
    }

    private let fileManager = FileManager.default

    func saveDefault(_ capture: PendingCapture, preferences: PreferencesStore) throws -> URL {
        try saveDefault(
            image: capture.image,
            capturedAt: capture.capturedAt,
            preferences: preferences
        )
    }

    func saveDefault(
        image: CGImage,
        capturedAt: Date,
        preferences: PreferencesStore
    ) throws -> URL {
        try fileManager.createDirectory(
            at: preferences.saveDirectory,
            withIntermediateDirectories: true
        )

        let destination = uniqueURL(
            in: preferences.saveDirectory,
            baseName: suggestedBaseName(for: capturedAt, preferences: preferences),
            pathExtension: preferences.fileFormat.rawValue
        )
        try writePNG(image, to: destination)
        AppLogger.storage.info("Saved screenshot to \(destination.path, privacy: .private(mask: .hash))")
        return destination
    }

    func saveAs(_ capture: PendingCapture, preferences: PreferencesStore) throws -> URL? {
        try saveAs(
            image: capture.image,
            capturedAt: capture.capturedAt,
            preferences: preferences
        )
    }

    func saveAs(
        image: CGImage,
        capturedAt: Date,
        preferences: PreferencesStore
    ) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Screenshot sichern"
        panel.nameFieldStringValue = suggestedFileName(
            for: capturedAt,
            preferences: preferences
        )
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let destination = panel.url else {
            return nil
        }

        try writePNG(image, to: destination)
        AppLogger.storage.info("Saved screenshot with Save As")
        return destination
    }

    func suggestedFileName(for capture: PendingCapture, preferences: PreferencesStore) -> String {
        suggestedFileName(for: capture.capturedAt, preferences: preferences)
    }

    func suggestedFileName(for capturedAt: Date, preferences: PreferencesStore) -> String {
        "\(suggestedBaseName(for: capturedAt, preferences: preferences)).\(preferences.fileFormat.rawValue)"
    }

    func copyToPasteboard(_ capture: PendingCapture) throws {
        try copyToPasteboard(capture.image)
    }

    func copyToPasteboard(_ image: CGImage) throws {
        let data = try pngData(for: image)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
    }

    func save(_ image: CGImage, to destination: URL) throws {
        try writePNG(image, to: destination)
        AppLogger.storage.info("Updated edited screenshot")
    }

    private func uniqueURL(in directory: URL, baseName: String, pathExtension: String) -> URL {
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(pathExtension)
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(baseName) \(suffix)")
                .appendingPathExtension(pathExtension)
            suffix += 1
        }

        return candidate
    }

    private func suggestedBaseName(
        for capturedAt: Date,
        preferences: PreferencesStore
    ) -> String {
        let proposedName = preferences.suggestedFilename(for: capturedAt)
        let extensionSuffix = ".\(preferences.fileFormat.rawValue)"

        if proposedName.lowercased().hasSuffix(extensionSuffix.lowercased()) {
            return String(proposedName.dropLast(extensionSuffix.count))
        }

        return proposedName
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        let data = try pngData(for: image)
        try data.write(to: url, options: .atomic)
    }

    private func pngData(for image: CGImage) throws -> Data {
        let data = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw StorageError.couldNotCreateImageDestination
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw StorageError.couldNotEncodePNG
        }

        return data as Data
    }
}
