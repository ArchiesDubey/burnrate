import AppKit
import SwiftUI

/// The app's appearance, as a user choice.
///
/// `system` leaves `NSApp.appearance` alone, so the app follows whatever the
/// Mac is set to; `light` and `dark` force it. Every colour in `Palette` is a
/// dynamic colour, so nothing else needs to know a theme exists — flipping
/// this repainting the notch, the tooltip and Settings is the window server's
/// job, not ours.
enum Theme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Match System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// Nil means "no opinion" — the app tracks the system appearance.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }
}
