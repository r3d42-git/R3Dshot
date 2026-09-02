//
//  ShortcutStore.swift
//  R3Dshot
//

import Foundation
import Observation

/// Persisted, observable shortcut settings shared by Settings, the menu bar and
/// the Carbon registration layer. The three stored values remain explicit so a
/// SwiftUI Settings view can bind to them directly.
@MainActor
@Observable
final class ShortcutStore {
    static let userDefaultsKey = "org.r3d.r3dshot.shortcuts.v1"

    var area: KeyboardShortcut {
        didSet {
            shortcutDidChange(.area, shortcut: area, oldValue: oldValue)
        }
    }

    var window: KeyboardShortcut {
        didSet {
            shortcutDidChange(.window, shortcut: window, oldValue: oldValue)
        }
    }

    var display: KeyboardShortcut {
        didSet {
            shortcutDidChange(.display, shortcut: display, oldValue: oldValue)
        }
    }

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var observers: [UUID: (CaptureAction, KeyboardShortcut) -> Void] = [:]
    @ObservationIgnored private var isRestoringRejectedValue = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let persisted = Self.load(from: userDefaults)
        area = persisted.area
        window = persisted.window
        display = persisted.display
    }

    func shortcut(for action: CaptureAction) -> KeyboardShortcut {
        switch action {
        case .area:
            area
        case .window:
            window
        case .display:
            display
        }
    }

    func displayString(for action: CaptureAction) -> String {
        shortcut(for: action).displayString
    }

    /// Returns false without modifying preferences when a recorder result has no key.
    @discardableResult
    func setShortcut(_ shortcut: KeyboardShortcut, for action: CaptureAction) -> Bool {
        guard shortcut.isValid else {
            return false
        }

        switch action {
        case .area:
            area = shortcut
        case .window:
            window = shortcut
        case .display:
            display = shortcut
        }

        return true
    }

    func resetToDefaults() {
        area = .defaultArea
        window = .defaultWindow
        display = .defaultDisplay
    }

    /// Consumers which do not use SwiftUI observation (Carbon and AppKit) use
    /// this narrow callback to rebuild their imperative state.
    @discardableResult
    func observeChanges(
        _ observer: @escaping (CaptureAction, KeyboardShortcut) -> Void
    ) -> UUID {
        let token = UUID()
        observers[token] = observer
        return token
    }

    func removeObserver(_ token: UUID) {
        observers[token] = nil
    }

    private func shortcutDidChange(
        _ action: CaptureAction,
        shortcut: KeyboardShortcut,
        oldValue: KeyboardShortcut
    ) {
        guard shortcut != oldValue else {
            return
        }

        if isRestoringRejectedValue {
            isRestoringRejectedValue = false
            return
        }

        guard shortcut.isValid else {
            isRestoringRejectedValue = true
            set(oldValue, for: action)
            return
        }

        persist()
        for observer in observers.values {
            observer(action, shortcut)
        }
    }

    private func set(_ shortcut: KeyboardShortcut, for action: CaptureAction) {
        switch action {
        case .area:
            area = shortcut
        case .window:
            window = shortcut
        case .display:
            display = shortcut
        }
    }

    private func persist() {
        let persisted = PersistedShortcuts(area: area, window: window, display: display)
        guard let data = try? JSONEncoder().encode(persisted) else {
            return
        }

        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }

    private static func load(from userDefaults: UserDefaults) -> PersistedShortcuts {
        guard
            let data = userDefaults.data(forKey: userDefaultsKey),
            let persisted = try? JSONDecoder().decode(PersistedShortcuts.self, from: data),
            persisted.area.isValid,
            persisted.window.isValid,
            persisted.display.isValid
        else {
            return .defaults
        }

        return persisted
    }
}

private struct PersistedShortcuts: Codable {
    var area: KeyboardShortcut
    var window: KeyboardShortcut
    var display: KeyboardShortcut

    static let defaults = PersistedShortcuts(
        area: .defaultArea,
        window: .defaultWindow,
        display: .defaultDisplay
    )
}
