import SwiftUI
import FamilyControls
import UserNotifications
import AVFoundation
import Speech

// MARK: - OnboardingView
//
// 6-step intro. Calm cadence — one decision per screen, large mascot, primary CTA.
// Steps 2-4 contextually request the actual iOS permissions.
// Step 5 transitions to the empty home / "+ block an app" entry.
//
// Translation of design_handoff_downbad/app/Onboarding.jsx (welcome + how it works
// + 3 permission steps + done).

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step = 0
    @StateObject private var blockManager = AppBlockManager.shared

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch step {
                    case 0: OnbWelcome { advance() }
                    case 1: OnbHowItWorks { advance() }
                    case 2: OnbPermission(
                        symbol: "shield.lefthalf.filled",
                        title: "screen time access",
                        body: "this lets us actually block apps. apple's api, no funny business.",
                        cta: "grant access",
                        footnote: "ios will ask. tap allow.",
                        mood: .judging,
                        action: { Task { try? await blockManager.requestAuthorization(); advance() } })
                    case 3: OnbPermission(
                        symbol: "camera",
                        title: "camera & mic",
                        body: "you'll say your phrase. we look + listen. nothing leaves your phone.",
                        cta: "continue",
                        footnote: nil,
                        mood: .sideeye,
                        action: { Task { _ = await SpeechRecognitionManager.requestPermissions(); requestCamera(); advance() } })
                    case 4: OnbPermission(
                        symbol: "bell.badge",
                        title: "notifications",
                        body: "when a blocked app is opened, the unlock button sends a notification that brings you here. we can't open downbad without it.",
                        cta: "allow",
                        footnote: "critical: without this, the shield button does nothing.",
                        mood: .shocked,
                        action: { requestNotifications(); advance() })
                    case 5: OnbDone { finish() }
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step) // force re-mount per step so transitions fire

                OnboardingDots(step: min(step, 5), total: 6)
                    .padding(.bottom, 16)
            }
        }
        .animation(.easeOut(duration: 0.3), value: step)
    }

    private func advance() { step = min(step + 1, 5) }

    private func finish() {
        SharedDefaults.shared.hasOnboarded = true
        onComplete()
    }

    private func requestCamera() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

// MARK: - Step 0: Welcome

private struct OnbWelcome: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Mascot(mood: .judging,
                   size: 170,
                   variant: .letterhead,
                   caption: "meet the judge")

            VStack(spacing: 16) {
                Text("meet the judge.")
                    .font(.serifItalic(48))
                    .tracking(-0.96)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(0)
                    .multilineTextAlignment(.center)

                Text("they will watch you say embarrassing things to your camera. it's for your own good.")
                    .font(.sans(17))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "say hi back", action: onNext)
                Text("30 seconds. promise.")
                    .font(.sans(12))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
    }
}

// MARK: - Step 1: How it works

private struct OnbHowItWorks: View {
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            Spacer().frame(height: 24)

            Text("here's the\ndeal.")
                .font(.serifItalic(44))
                .tracking(-0.88)
                .foregroundStyle(Theme.ink)
                .lineSpacing(-2)

            VStack(alignment: .leading, spacing: 24) {
                StepRow(n: "1", title: "pick an app to block",
                        body: "the one you keep falling into. you know.")
                StepRow(n: "2", title: "pick an embarrassing phrase",
                        body: "something you'd rather not say in a quiet room.")
                StepRow(n: "3", title: "say it out loud to unlock",
                        body: "we'll be watching. (also, your camera.)")
            }

            Spacer()

            PrimaryButton(title: "got it", action: onNext)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
    }

    private struct StepRow: View {
        let n: String
        let title: String
        let body: String

        var body: some View {
            HStack(alignment: .top, spacing: 16) {
                Text(n)
                    .font(.serifItalic(18))
                    .foregroundStyle(Theme.cream)
                    .frame(width: 32, height: 32)
                    .background(Theme.ink)
                    .clipShape(Circle())
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.sans(17, weight: .semibold))
                        .tracking(-0.17)
                        .foregroundStyle(Theme.ink)
                    Text(body)
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkMuted)
                        .lineSpacing(2)
                }
            }
        }
    }
}

// MARK: - Steps 2/3/4: Permissions

private struct OnbPermission: View {
    let symbol: String
    let title: String
    let body: String
    let cta: String
    let footnote: String?
    let mood: MascotMood
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Theme.ink)
                        Image(systemName: symbol)
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(Theme.cream)
                    }
                    .frame(width: 72, height: 72)

                    Spacer()

                    Mascot(mood: mood, size: 70)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(title)
                        .font(.serifItalic(40))
                        .tracking(-0.8)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(-2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(body)
                        .font(.sans(16))
                        .foregroundStyle(Theme.inkMuted)
                        .lineSpacing(3)
                }

                if let footnote {
                    Text(footnote)
                        .font(.mono(11))
                        .foregroundStyle(Theme.inkFaint)
                        .lineSpacing(3)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.creamSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.creamDeep, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Spacer()

            PrimaryButton(title: cta, action: action)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
    }
}

// MARK: - Step 5: Done

private struct OnbDone: View {
    let onNext: () -> Void
    @State private var phase = 0
    private let cycleTimer = Timer.publish(every: 1.4, on: .main, in: .common).autoconnect()
    private let cycleMoods: [MascotMood] = [.smitten, .wink, .smirk]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Mascot(mood: cycleMoods[phase], size: 140)
                .animation(.easeInOut(duration: 0.3), value: phase)

            VStack(spacing: 16) {
                Text("we're set.")
                    .font(.serifItalic(48))
                    .tracking(-0.96)
                    .foregroundStyle(Theme.ink)

                Text("let's pick the first app you'd like\nto gently disappoint yourself with.")
                    .font(.sans(16))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()

            PrimaryButton(title: "pick an app", action: onNext)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .onReceive(cycleTimer) { _ in phase = (phase + 1) % cycleMoods.count }
    }
}

#if DEBUG
#Preview {
    OnboardingView(onComplete: {})
}
#endif
