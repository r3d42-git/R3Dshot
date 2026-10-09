import AppKit

/// Shared, appearance-aware surfaces for the editor and its native title bar.
enum EditorAppearance {
    static let canvas = surface("Canvas", dark: (37, 54, 74), light: .underPageBackgroundColor)
    static let panel = surface("Panel", dark: (44, 63, 85), light: .windowBackgroundColor)
    static let titlebar = surface("Titlebar", dark: (52, 73, 96), light: .windowBackgroundColor)

    private static func surface(_ name: String, dark: (CGFloat, CGFloat, CGFloat), light: NSColor) -> NSColor {
        NSColor(name: NSColor.Name("R3Dshot.Editor.\(name)")) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(srgbRed: dark.0 / 255, green: dark.1 / 255, blue: dark.2 / 255, alpha: 1)
            }
            return light
        }
    }
}
