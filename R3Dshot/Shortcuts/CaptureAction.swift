//
//  CaptureAction.swift
//  R3Dshot
//
//  The small, UI-independent vocabulary shared by menu items and global hotkeys.
//

import Foundation

enum CaptureAction: String, CaseIterable, Codable, Hashable, Sendable {
    case area
    case window
    case display

    var menuTitle: String {
        switch self {
        case .area:
            "Bereich aufnehmen"
        case .window:
            "Fenster aufnehmen"
        case .display:
            "Bildschirm aufnehmen"
        }
    }

    /// Stable IDs used only inside this process for Carbon hotkey callbacks.
    var hotKeyID: UInt32 {
        switch self {
        case .area:
            1
        case .window:
            2
        case .display:
            3
        }
    }

    /// Stable tags for the three corresponding NSMenuItems.
    var menuItemTag: Int {
        Int(hotKeyID)
    }

    init?(hotKeyID: UInt32) {
        switch hotKeyID {
        case 1:
            self = .area
        case 2:
            self = .window
        case 3:
            self = .display
        default:
            return nil
        }
    }

    init?(menuItemTag: Int) {
        self.init(hotKeyID: UInt32(exactly: menuItemTag) ?? 0)
    }
}
