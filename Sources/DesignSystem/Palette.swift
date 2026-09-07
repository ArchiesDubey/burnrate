import SwiftUI

/// Sampled from `docs/design/frame-124-hover-tooltip.png`, not invented.
///
/// Note these differ slightly from the hexes written in the design spec — the
/// frame is the source of truth, so the sampled values win.
///
/// Every colour is dynamic: it carries a light and a dark value and resolves
/// against the app's effective appearance, so light/dark mode is not a second
/// set of call sites but the same names answering differently. The app's
/// appearance is driven by `Theme` (`NSApp.appearance`), which makes "Match
/// System" the default and a forced mode a preference.
enum Palette {
    // `let`, not `var`: one shared colour object per name keeps `==` stable,
    // which SwiftUI diffing and the tests both rely on. Dynamism lives inside
    // the NSColor, which resolves against the effective appearance at draw.
    static let notch: Color         = dynamic(light: 0xFFFFFF, dark: 0x000000)
    static let card: Color          = dynamic(light: 0xFFFFFF, dark: 0x000000)
    static let ringTrack: Color     = dynamic(light: 0xDCDCDC, dark: 0x303030)
    static let barTrack: Color      = dynamic(light: 0xE3E3E3, dark: 0x2D2D2D)

    /// The accents are saturated neons designed on black. On white they would
    /// glow past legibility, so the light variants are the same hues pulled
    /// down to pigment — the dark ones stay exactly as sampled from the frame.
    static let ample: Color         = dynamic(light: 0x00A05F, dark: 0x00FF88)
    static let watch: Color         = dynamic(light: 0x9C9C00, dark: 0xF2FF00)
    static let critical: Color      = dynamic(light: 0xE63800, dark: 0xFF3F00)

    static let textPrimary: Color   = dynamic(light: 0x000000, dark: 0xFFFFFF)

    /// Two reading greys, both measured against their own background: the
    /// light variants hold ≥4.5:1 on white (SwiftUI's `.secondary`/`.tertiary`
    /// resolve to ~2:1 in light mode, which nobody could read), the dark ones
    /// keep the sampled hierarchy on black.
    static let textSecondary: Color = dynamic(light: 0x55555C, dark: 0x808080)
    static let textTertiary: Color  = dynamic(light: 0x73737B, dark: 0x6E6E73)

    /// One dynamic colour from a light and a dark hex. `NSColor(name:)`'s
    /// provider is consulted whenever the effective appearance changes, which
    /// is what makes a theme flip repaint every surface at once.
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

extension NSAppearance {
    /// The standard test for "which variant of a dynamic colour": whether any
    /// dark appearance is the best match for this one.
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .vibrantDark]) != nil
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed:   Double((hex >> 16) & 0xFF) / 255,
            green:     Double((hex >> 8) & 0xFF) / 255,
            blue:      Double(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
