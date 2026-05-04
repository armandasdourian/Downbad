import SwiftUI

// MARK: - Mascot — THE judge
//
// Manga face on a cream paper sheet. The brand. Used everywhere.
//
// Translation of design_handoff_downbad/app/Mascot.jsx.
// Two body variants:
//   .paper      — square sheet (default, works as avatar/inline/full-screen)
//   .letterhead — 4:5 portrait document with case-no caption (hero only)
//
// Face PNGs are 400×500 with content centered at (200, 250), max content dim 280.
// To make the face fill `fit` of the container's shorter side, scale by
// `fit / (280/500)` since `.scaledToFit()` already does the contain pass.

enum MascotMood: String, CaseIterable {
    case idle, flat, listening, judging, unimpressed, sideeye
    case disappointed, concerned, sleepy, smirk, wink
    case shocked, cry, angry, smitten

    /// Convenience aliases used in the design. All map to one of the canonical 15.
    static func from(_ alias: String) -> MascotMood {
        switch alias.lowercased() {
        case "eyeroll": return .sideeye
        case "gone":    return .sleepy
        case "happy":   return .smitten
        case "sus":     return .sideeye
        case "shy":     return .concerned
        default:        return MascotMood(rawValue: alias.lowercased()) ?? .idle
        }
    }

    /// Asset name in the catalog. Faces are namespaced under `Faces/`.
    var imageName: String { "Faces/\(rawValue)" }
}

enum MascotVariant {
    case paper       // 1:1 square
    case letterhead  // 4:5 with caption + case number
}

struct Mascot: View {
    var mood: MascotMood = .idle
    var size: CGFloat = 140
    var variant: MascotVariant = .paper
    var caption: String? = nil      // letterhead only
    var listening: Bool = false
    var breathing: Bool = true
    /// Override paper color (e.g., to sit on a darker context).
    var paperColor: Color = Theme.cream

    @State private var breathPhase: Double = 0

    var body: some View {
        Group {
            switch variant {
            case .paper:      paper
            case .letterhead: letterhead
            }
        }
        .scaleEffect(x: breathing ? 1 + breathPhase * 0.018 : 1,
                     y: breathing ? 1 - breathPhase * 0.018 : 1,
                     anchor: .center)
        .onAppear {
            guard breathing else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                breathPhase = 1
            }
        }
    }

    // MARK: Variants

    private var paper: some View {
        ZStack {
            paperColor
            FaceImage(mood: mood, fit: 0.78)
                .padding(2) // edge breathing room

            // 1px ink border
            Rectangle()
                .stroke(Theme.ink.opacity(0.13), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .overlay(listeningRing.opacity(listening ? 1 : 0))
    }

    private var letterhead: some View {
        let h = size * 1.25
        return VStack(spacing: 0) {
            // Face — top half
            FaceImage(mood: mood, fit: 0.92)
                .frame(maxWidth: .infinity)
                .frame(height: h * 0.50)
                .padding(.top, h * 0.02)
                .padding(.horizontal, size * 0.06)

            // Divider + text — bottom half
            VStack(spacing: size * 0.025) {
                Rectangle()
                    .fill(Theme.ink)
                    .frame(height: 1)
                    .padding(.horizontal, size * 0.0)

                Text(caption ?? "notice of judgment")
                    .font(.serifItalic(size * 0.085))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(caseNumber)
                    .font(.mono(size * 0.04))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .tracking(size * 0.04 * 0.12)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, size * 0.12)
            .padding(.top, size * 0.045)
        }
        .frame(width: size, height: h)
        .background(paperColor)
        .shadow(color: Color.black.opacity(0.08), radius: 7, x: 0, y: 4)
        .overlay(listeningRing.opacity(listening ? 1 : 0))
    }

    private var caseNumber: String {
        // Generate a fake case number from mood for verisimilitude — matches design.
        let suffix = String(mood.rawValue.prefix(3))
        return "case no. 0421-\(suffix)"
    }

    // MARK: Listening pulse

    private var listeningRing: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let phase = (sin(t * 2 * .pi / 1.6) + 1) / 2 // 0..1, 1.6s period
            Rectangle()
                .stroke(Theme.pulse, lineWidth: 2)
                .padding(-3)
                .opacity(0.4 + phase * 0.5)
                .scaleEffect(1 + phase * 0.05)
        }
    }
}

// MARK: - FaceImage
//
// Renders one of the 15 PNG faces, scaled so the brushwork fills `fit` of
// the container's shorter side. Native fraction is 280/500 = 0.56.

private struct FaceImage: View {
    let mood: MascotMood
    var fit: CGFloat = 0.92

    var body: some View {
        let scale = fit / (280.0 / 500.0)
        Image(mood.imageName)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Paper grid") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(MascotMood.allCases, id: \.self) { mood in
                VStack(spacing: 6) {
                    Mascot(mood: mood, size: 80)
                    Text(mood.rawValue).font(.mono(10)).foregroundStyle(Theme.inkMuted)
                }
            }
        }
        .padding()
    }
    .background(Theme.cream)
}

#Preview("Letterhead — judging") {
    Mascot(mood: .judging, size: 170, variant: .letterhead, caption: "meet the judge")
        .padding(40)
        .background(Theme.cream)
}

#Preview("Listening") {
    Mascot(mood: .listening, size: 140, listening: true)
        .padding(40)
        .background(Theme.cream)
}
#endif
