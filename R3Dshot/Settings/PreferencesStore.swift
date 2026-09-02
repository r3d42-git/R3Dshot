import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class PreferencesStore {
    enum FileFormat: String, CaseIterable, Identifiable {
        case png

        var id: String { rawValue }
        var displayName: String { rawValue.uppercased() }
    }

    private enum Key {
        static let saveDirectoryPath = "saveDirectoryPath"
        static let fileFormat = "fileFormat"
        static let filenamePattern = "filenamePattern"
        static let launchAtLogin = "launchAtLogin"
        static let includeWindowShadow = "includeWindowShadow"
        static let includeMouseCursor = "includeMouseCursor"
        static let showsQuickActionPanel = "showsQuickActionPanel"
    }

    private let defaults: UserDefaults

    var saveDirectoryPath: String {
        didSet { defaults.set(saveDirectoryPath, forKey: Key.saveDirectoryPath) }
    }

    var fileFormatRawValue: String {
        didSet { defaults.set(fileFormatRawValue, forKey: Key.fileFormat) }
    }

    var filenamePattern: String {
        didSet { defaults.set(filenamePattern, forKey: Key.filenamePattern) }
    }

    var includeWindowShadow: Bool {
        didSet { defaults.set(includeWindowShadow, forKey: Key.includeWindowShadow) }
    }

    var includeMouseCursor: Bool {
        didSet { defaults.set(includeMouseCursor, forKey: Key.includeMouseCursor) }
    }

    var showsQuickActionPanel: Bool {
        didSet { defaults.set(showsQuickActionPanel, forKey: Key.showsQuickActionPanel) }
    }

    private(set) var launchAtLogin: Bool
    private(set) var loginItemError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.saveDirectoryPath = defaults.string(forKey: Key.saveDirectoryPath)
            ?? Self.defaultSaveDirectory.path
        self.fileFormatRawValue = defaults.string(forKey: Key.fileFormat)
            ?? FileFormat.png.rawValue
        self.filenamePattern = defaults.string(forKey: Key.filenamePattern)
            ?? "R3Dshot yyyy-MM-dd 'um' HH.mm.ss"
        self.includeWindowShadow = defaults.object(forKey: Key.includeWindowShadow) as? Bool ?? true
        self.includeMouseCursor = defaults.object(forKey: Key.includeMouseCursor) as? Bool ?? false
        self.showsQuickActionPanel = defaults.object(forKey: Key.showsQuickActionPanel) as? Bool ?? true
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    var saveDirectory: URL {
        URL(fileURLWithPath: saveDirectoryPath, isDirectory: true)
    }

    var fileFormat: FileFormat {
        get { FileFormat(rawValue: fileFormatRawValue) ?? .png }
        set { fileFormatRawValue = newValue.rawValue }
    }

    func suggestedFilename(for date: Date) -> String {
        let renderedName = renderFilenamePattern(for: date)
        let safeName = renderedName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return safeName.isEmpty ? "R3Dshot" : safeName
    }

    /// The settings field accepts the familiar date tokens `yyyy`, `MM`, `dd`,
    /// `HH`, `mm` and `ss`. Text outside a token is always literal, so a prefix
    /// such as "R3Dshot" cannot accidentally be interpreted as a date format.
    private func renderFilenamePattern(for date: Date) -> String {
        let pattern = filenamePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else {
            return "R3Dshot"
        }

        var result = ""
        var index = pattern.startIndex

        while index < pattern.endIndex {
            if pattern[index] == "'" {
                let literalStart = pattern.index(after: index)
                guard let literalEnd = pattern[literalStart...].firstIndex(of: "'") else {
                    result += String(pattern[literalStart...])
                    break
                }
                result += String(pattern[literalStart..<literalEnd])
                index = pattern.index(after: literalEnd)
                continue
            }

            if pattern[index].isLetter {
                let tokenStart = index
                while index < pattern.endIndex, pattern[index].isLetter {
                    index = pattern.index(after: index)
                }

                let candidate = String(pattern[tokenStart..<index])
                result += renderedDateTokenRun(candidate, for: date) ?? candidate
                continue
            }

            result.append(pattern[index])
            index = pattern.index(after: index)
        }

        return result
    }

    private func renderedDateTokenRun(_ candidate: String, for date: Date) -> String? {
        let supportedTokens = ["yyyy", "yy", "MM", "dd", "HH", "mm", "ss", "M", "d", "H", "m", "s"]
        var remaining = candidate[...]

        while !remaining.isEmpty {
            guard let token = supportedTokens.first(where: { remaining.hasPrefix($0) }) else {
                return nil
            }
            remaining.removeFirst(token.count)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = candidate
        return formatter.string(from: date)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemError = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loginItemError = error.localizedDescription
            AppLogger.application.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static var defaultSaveDirectory: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("R3Dshot", isDirectory: true)
    }
}
