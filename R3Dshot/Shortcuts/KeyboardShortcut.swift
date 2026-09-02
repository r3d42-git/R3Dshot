//
//  KeyboardShortcut.swift
//  R3Dshot
//

import AppKit
import Carbon

/// The modifier subset accepted by Carbon's `RegisterEventHotKey` API.
struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt32

    static let command = ShortcutModifiers(rawValue: UInt32(cmdKey))
    static let option = ShortcutModifiers(rawValue: UInt32(optionKey))
    static let shift = ShortcutModifiers(rawValue: UInt32(shiftKey))
    static let control = ShortcutModifiers(rawValue: UInt32(controlKey))

    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    init(eventModifiers: NSEvent.ModifierFlags) {
        var modifiers: ShortcutModifiers = []

        if eventModifiers.contains(.command) {
            modifiers.insert(.command)
        }
        if eventModifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if eventModifiers.contains(.shift) {
            modifiers.insert(.shift)
        }
        if eventModifiers.contains(.control) {
            modifiers.insert(.control)
        }

        self = modifiers
    }

    var eventModifiers: NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []

        if contains(.command) {
            modifiers.insert(.command)
        }
        if contains(.option) {
            modifiers.insert(.option)
        }
        if contains(.shift) {
            modifiers.insert(.shift)
        }
        if contains(.control) {
            modifiers.insert(.control)
        }

        return modifiers
    }

    /// Native modifier-glyph order, suitable for a menu's shortcut column.
    var displaySymbols: String {
        var symbols = ""

        if contains(.control) {
            symbols += "⌃"
        }
        if contains(.option) {
            symbols += "⌥"
        }
        if contains(.shift) {
            symbols += "⇧"
        }
        if contains(.command) {
            symbols += "⌘"
        }

        return symbols
    }
}

struct KeyboardShortcut: Codable, Hashable, Sendable {
    /// A macOS virtual keycode, as delivered by `NSEvent.keyCode`.
    let keyCode: UInt32
    let modifiers: ShortcutModifiers
    /// The user-facing key name captured by the shortcut recorder, for example `F13`.
    let displayName: String

    init(keyCode: UInt32, modifiers: ShortcutModifiers = [], displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayString: String {
        modifiers.displaySymbols + displayName
    }

    /// A shortcut always has a virtual keycode. A keycode of zero is valid on macOS,
    /// so only an empty display name makes a recorder result invalid.
    var isValid: Bool {
        !displayName.isEmpty
    }
}

extension KeyboardShortcut {
    static let defaultArea = KeyboardShortcut(
        keyCode: UInt32(kVK_F13),
        displayName: "F13"
    )

    static let defaultWindow = KeyboardShortcut(
        keyCode: UInt32(kVK_F13),
        modifiers: .option,
        displayName: "F13"
    )

    static let defaultDisplay = KeyboardShortcut(
        keyCode: UInt32(kVK_F13),
        modifiers: .control,
        displayName: "F13"
    )
}
