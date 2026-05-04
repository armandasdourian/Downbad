import SwiftUI

// MARK: - Design Tokens
//
// Translation of design_handoff_downbad/app/tokens.js into SwiftUI.
// Cream paper background, ink text, terracotta clay accents, sage for unlocked.
// Italic serif for titles, system sans for body, mono for tiny captions.
//
// Fonts: the design specifies Instrument Serif / Inter / JetBrains Mono.
// None of those ship on iOS. We use SwiftUI's `.serif` design (renders New York)
// for italic titles, system default for body, and `.monospaced` design for captions.
// To match the design pixel-for-pixel, drop Instrument Serif font files into
// Downbad/Resources/Fonts/ and add them to UIAppFonts in Info.plist; then change
// `Font.serif(...)` below to `Font.custom("InstrumentSerif-Italic", ...)`.

enum Theme {
    // MARK: Colors

    static let cream     = Color(red: 0.961, green: 0.941, blue: 0.910) // #F5F0E8
    static let creamSoft = Color(red: 0.937, green: 0.910, blue: 0.863) // #EFE8DC
    static let creamDeep = Color(red: 0.910, green: 0.875, blue: 0.808) // #E8DFCE
    static let ink       = Color(red: 0.102, green: 0.094, blue: 0.078) // #1A1814
    static let inkSoft   = Color(red: 0.227, green: 0.204, blue: 0.173) // #3A342C
    static let inkMuted  = Color(red: 0.420, green: 0.392, blue: 0.353) // #6B645A
    static let inkFaint  = Color(red: 0.659, green: 0.627, blue: 0.584) // #A8A095

    // Clay (dusty terracotta) — accents, primary actions
    static let clay      = Color(red: 0.776, green: 0.502, blue: 0.341) // ≈ oklch(0.68 0.12 40)
    static let claySoft  = Color(red: 0.847, green: 0.635, blue: 0.494)
    static let clayDeep  = Color(red: 0.620, green: 0.357, blue: 0.220) // ≈ oklch(0.55 0.13 40)

    // Sage (unlocked + listening pulse)
    static let sage      = Color(red: 0.737, green: 0.808, blue: 0.745) // ≈ oklch(0.78 0.04 145)
    static let sageDeep  = Color(red: 0.498, green: 0.612, blue: 0.529) // ≈ oklch(0.62 0.06 145)

    // Blush (soft warning)
    static let blush     = Color(red: 0.886, green: 0.808, blue: 0.776)

    // Listening pulse glow (bright red-orange ring)
    static let pulse     = Color(red: 0.890, green: 0.392, blue: 0.220)

    // MARK: Radii

    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 28          // pill — matches 56pt button height
    static let appIconRadius: CGFloat = 11

    // MARK: Spacing

    static let screenPadX: CGFloat = 24
    static let cardPad: CGFloat = 16
    static let cardGap: CGFloat = 10
    static let sectionGap: CGFloat = 28
}

// MARK: - Font helpers
//
// All sizes match the design. Use these everywhere instead of `.font(.title)` etc.

extension Font {

    /// Italic serif — wordmark, screen titles, quoted phrases. Design uses Instrument Serif.
    static func serifItalic(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif).italic()
    }

    /// Body sans — design uses Inter; we fall through to SF Pro.
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Mono caption — design uses JetBrains Mono; we use SF Mono.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Convenience modifiers

extension View {

    /// Standard "uppercase mono caption" treatment — section headers, status pills.
    func captionMono() -> some View {
        self
            .font(.mono(11, weight: .semibold))
            .foregroundStyle(Theme.inkFaint)
            .textCase(.uppercase)
            .tracking(0.08 * 11)
    }

    /// Cream background that fills the entire screen, ignoring safe areas.
    func creamBackground() -> some View {
        self.background(Theme.cream.ignoresSafeArea())
    }
}
