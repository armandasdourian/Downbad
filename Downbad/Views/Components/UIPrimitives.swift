import SwiftUI

// MARK: - Primary button
//
// 56pt tall, full-width, pill-shaped. Ink fill by default. Translates the
// design's PrimaryButton (UI.jsx).

enum PrimaryButtonVariant {
    case ink     // black on cream — default
    case clay    // terracotta on cream
    case ghost   // transparent with ink border
}

struct PrimaryButton: View {
    let title: String
    var variant: PrimaryButtonVariant = .ink
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            Text(title)
                .font(.sans(17, weight: .semibold))
                .tracking(-0.17)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(foreground)
                .background(background)
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(variant == .ghost ? Theme.ink : .clear,
                                lineWidth: 1.5)
                )
                .opacity(disabled ? 0.55 : 1)
        }
        .buttonStyle(PressScale())
        .disabled(disabled)
    }

    private var background: Color {
        if disabled { return Theme.creamDeep }
        switch variant {
        case .ink:   return Theme.ink
        case .clay:  return Theme.clay
        case .ghost: return .clear
        }
    }

    private var foreground: Color {
        if disabled { return Theme.inkFaint }
        switch variant {
        case .ink, .clay: return Theme.cream
        case .ghost:      return Theme.ink
        }
    }
}

// MARK: - Ghost button

struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.sans(15, weight: .medium))
                .tracking(-0.15)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .foregroundStyle(Theme.inkMuted)
        }
        .buttonStyle(PressScale())
    }
}

// MARK: - Press-scale style — used by all tappable surfaces

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Card — translucent cream surface

struct Card<Content: View>: View {
    var padded: Bool = true
    var fill: Color = Theme.creamSoft
    var stroke: Color = Theme.creamDeep
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padded ? Theme.cardPad : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}

// MARK: - Pill — status chip
//
// Used for "locked", "re-lock", "authorized", etc.

enum PillTone {
    case neutral, locked, unlocked, clay, warn, sageDot
}

struct Pill: View {
    let text: String
    var tone: PillTone = .neutral
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.sans(10, weight: .semibold))
            }
            Text(text)
                .font(.sans(11, weight: .semibold))
                .tracking(0.22)
                .textCase(.lowercase)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(bg)
        .clipShape(Capsule(style: .continuous))
    }

    private var bg: Color {
        switch tone {
        case .neutral:  return Theme.creamDeep
        case .locked:   return Theme.ink
        case .unlocked: return Theme.sage
        case .clay:     return Theme.clay
        case .warn:     return Color(red: 0.918, green: 0.792, blue: 0.510)
        case .sageDot:  return Theme.creamDeep
        }
    }
    private var fg: Color {
        switch tone {
        case .neutral, .unlocked, .warn, .sageDot: return Theme.inkSoft
        case .locked, .clay:                       return Theme.cream
        }
    }
}

// MARK: - AppIconView
//
// Colorful gradient swatch for an app — falls back to a default brand gradient
// when the name isn't known. The current implementation uses the app's
// localizedDisplayName (from FamilyControls) as the lookup key.

struct AppIconView: View {
    let name: String
    var size: CGFloat = 44
    var radius: CGFloat = Theme.appIconRadius

    var body: some View {
        let pal = Self.palette(for: name)
        let initial = String(name.prefix(1)).uppercased()

        ZStack {
            if pal.count >= 3 {
                AngularGradient(colors: pal + [pal[0]],
                                center: .center,
                                startAngle: .degrees(200),
                                endAngle: .degrees(560))
            } else {
                LinearGradient(colors: pal,
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            }
            Text(initial)
                .font(.sans(size * 0.42, weight: .bold))
                .tracking(-size * 0.42 * 0.02)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 1.5, x: 0, y: 1)
    }

    private static func palette(for name: String) -> [Color] {
        let key = name.lowercased()
        if key.contains("instagram") { return [.init(hex: 0xFEDA75), .init(hex: 0xFA7E1E), .init(hex: 0xD62976), .init(hex: 0x962FBF), .init(hex: 0x4F5BD5)] }
        if key.contains("tiktok")    { return [.init(hex: 0x010101), .init(hex: 0xFF0050), .init(hex: 0x00F2EA)] }
        if key == "x" || key.contains("twitter") { return [.init(hex: 0x000000), .init(hex: 0x1A1A1A)] }
        if key.contains("youtube")   { return [.init(hex: 0xFF0000), .init(hex: 0xCC0000)] }
        if key.contains("reddit")    { return [.init(hex: 0xFF4500), .init(hex: 0xFF6314)] }
        if key.contains("snapchat")  { return [.init(hex: 0xFFFC00), .init(hex: 0xF8E71C)] }
        if key.contains("facebook")  { return [.init(hex: 0x1877F2), .init(hex: 0x0E5CB6)] }
        if key.contains("discord")   { return [.init(hex: 0x5865F2), .init(hex: 0x4752C4)] }
        if key.contains("pinterest") { return [.init(hex: 0xE60023), .init(hex: 0xBD081C)] }
        if key.contains("linkedin")  { return [.init(hex: 0x0A66C2), .init(hex: 0x004182)] }
        if key.contains("twitch")    { return [.init(hex: 0x9146FF), .init(hex: 0x6441A4)] }
        if key.contains("netflix")   { return [.init(hex: 0xE50914), .init(hex: 0xB81D24)] }
        if key.contains("spotify")   { return [.init(hex: 0x1DB954), .init(hex: 0x169C46)] }
        if key.contains("safari")    { return [.init(hex: 0x1B7EE5), .init(hex: 0x5BD3FA)] }
        // default — clay terracotta gradient
        return [Theme.clay, Theme.clayDeep]
    }
}

// MARK: - Section header (mono caps)

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .captionMono()
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
    }
}

// MARK: - Onboarding progress dots

struct OnboardingDots: View {
    let step: Int
    let total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Theme.ink : Theme.creamDeep)
                    .frame(width: i == step ? 22 : 6, height: 6)
                    .animation(.easeOut(duration: 0.25), value: step)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Buttons") {
    VStack(spacing: 12) {
        PrimaryButton(title: "say hi back") {}
        PrimaryButton(title: "block it", variant: .clay) {}
        PrimaryButton(title: "ghost", variant: .ghost) {}
        PrimaryButton(title: "disabled", disabled: true) {}
        GhostButton(title: "not right now") {}
    }
    .padding()
    .background(Theme.cream)
}

#Preview("Cards & pills") {
    VStack(alignment: .leading, spacing: 12) {
        Card {
            HStack {
                AppIconView(name: "Instagram", size: 44)
                VStack(alignment: .leading) {
                    Text("Instagram").font(.sans(16, weight: .semibold))
                    Text("\"i have no self control...\"").font(.serifItalic(13)).foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                Pill(text: "locked", tone: .locked, systemImage: "lock.fill")
            }
        }
        Card(fill: Theme.sage.opacity(0.6)) {
            HStack {
                AppIconView(name: "TikTok", size: 44)
                VStack(alignment: .leading) {
                    Text("TikTok").font(.sans(16, weight: .semibold))
                    Text("unlocks for 11m 58s").font(.sans(12)).foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                Pill(text: "re-lock", tone: .clay)
            }
        }
        OnboardingDots(step: 2, total: 6)
    }
    .padding()
    .background(Theme.cream)
}
#endif
