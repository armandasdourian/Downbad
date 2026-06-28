import SwiftUI

// MARK: - UnlockSuccessView
//
// Plays after a successful match. Mascot eye-rolls, then settles into
// `unimpressed`, then a sarcastic blessing line + "go on then" CTA.
//
// Translation of UnlockSuccess in design_handoff_downbad/app/Unlock.jsx.

struct UnlockSuccessView: View {
    let app: BlockedAppConfig
    let onContinue: () -> Void

    @State private var phase: Phase = .roll

    private enum Phase { case roll, settle, caption }

    /// Sarcastic blessing — picked once on appear so it doesn't shuffle on re-renders.
    @State private var line: String = Self.lines.randomElement() ?? Self.lines[0]

    private static let lines = [
        "alright. if you insist.",
        "fine. go ahead.",
        "okay. on your conscience.",
        "sure. that's allowed apparently.",
    ]

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Mascot(mood: phase == .roll ? .sideeye : .unimpressed,
                       size: 150)
                    .animation(.easeInOut(duration: 0.4), value: phase)

                VStack(spacing: 14) {
                    Text(line)
                        .font(.serifItalic(38))
                        .tracking(-0.76)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .opacity(phase == .roll ? 0 : 1)
                        .offset(y: phase == .roll ? 8 : 0)
                        .animation(.easeOut(duration: 0.4), value: phase)

                    if phase == .caption {
                        VStack(spacing: 4) {
                            Text("\(app.displayName) is open for \(durationLabel(app.unlockDuration)).")
                                .font(.sans(15))
                                .foregroundStyle(Theme.inkMuted)
                            Text("see you back here in a bit.")
                                .font(.serifItalic(15))
                                .foregroundStyle(Theme.inkMuted)
                        }
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                if phase == .caption {
                    PrimaryButton(title: "go on then", action: onContinue)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                } else {
                    Color.clear.frame(height: 56)
                }
            }
            .padding(.bottom, 32)
        }
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { phase = .settle }
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation { phase = .caption }
        }
    }

    private func durationLabel(_ d: UnlockDuration) -> String {
        switch d {
        case .fiveMinutes:    return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes:  return "30 minutes"
        case .oneHour:        return "an hour"
        case .twoHours:       return "2 hours"
        case .fourHours:      return "4 hours"
        case .restOfDay:      return "the rest of the day"
        }
    }
}

// MARK: - UnlockMismatchOverlay
//
// Slides up over the unlock screen when the phrase fails to match.
// Disappointed letterhead mascot with case caption "motion denied".

struct UnlockMismatchOverlay: View {
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 20) {
                Mascot(mood: .disappointed,
                       size: 140,
                       variant: .letterhead,
                       caption: "motion denied")

                Text("that wasn't it.")
                    .font(.serifItalic(32))
                    .tracking(-0.64)
                    .foregroundStyle(Theme.cream)

                Text("the judge heard something else.\nsay the whole phrase, slowly.")
                    .font(.sans(14))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                HStack(spacing: 10) {
                    Button(action: onClose) {
                        Text("not now")
                            .font(.sans(14, weight: .semibold))
                            .foregroundStyle(Theme.cream)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(PressScale())

                    Button(action: onRetry) {
                        Text("try again")
                            .font(.sans(14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Theme.cream)
                            .clipShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(PressScale())
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)
        }
    }
}
