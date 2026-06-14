import SwiftUI
import UIKit

/// Central design tokens. Everything visual references `Theme` so the look is consistent
/// and a restyle is a single-file change. Colors adapt to light/dark automatically.
///
/// Brand: **monochrome** — pure black/white with a precise, premium feel. Differentiation
/// comes from fill vs. outline and type weight, not hue.
enum Theme {

    // MARK: Colors (black & white system)
    static let background      = Color(light: 0xF4F4F5, dark: 0x000000)
    static let surface         = Color(light: 0xFFFFFF, dark: 0x111113)
    static let surfaceElevated  = Color(light: 0xFFFFFF, dark: 0x1B1B1E)
    static let separator       = Color(light: 0xE3E3E6, dark: 0x2B2B2F)

    static let textPrimary     = Color(light: 0x09090B, dark: 0xFAFAFA)
    static let textSecondary   = Color(light: 0x6B6B72, dark: 0x9B9BA2)
    static let textTertiary    = Color(light: 0xACACB2, dark: 0x636369)

    /// Primary action color: black in light mode, white in dark mode.
    static let accent          = Color(light: 0x09090B, dark: 0xFAFAFA)
    /// Foreground that sits ON `accent` (e.g. button text): the inverse of `accent`.
    static let onAccent        = Color(light: 0xFFFFFF, dark: 0x000000)

    /// Semantic tones — kept monochrome. Sold reads as the strong tone, active as muted.
    static let sold            = Color(light: 0x09090B, dark: 0xFAFAFA)
    static let active          = Color(light: 0x6B6B72, dark: 0x9B9BA2)

    // MARK: Spacing
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Corner radius
    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: Type
    /// Tabular, rounded numerals for prices — modern and easy to scan.
    static func price(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Color helpers

extension Color {
    /// Build a color from light/dark hex values that resolves at runtime.
    init(light: UInt, dark: UInt) {
        self = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue:  CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Reusable view styling

extension View {
    /// Standard elevated card surface used across the app.
    func cardSurface(padding: CGFloat = Theme.Space.lg,
                     cornerRadius: CGFloat = Theme.Radius.md) -> some View {
        self
            .padding(padding)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            )
    }
}
