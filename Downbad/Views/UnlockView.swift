import SwiftUI
import AVFoundation
import UIKit

// MARK: - UnlockView (Playful variant)
//
// The heart of the product, in two acts:
//
//   1. MIRROR — the camera fills the screen and the user must look at
//      themselves for a moment. The progress bar only advances while a face
//      is actually detected in frame (Vision, see CameraManager). The judge
//      stares, deadpan.
//   2. SPEAK — the phrase card appears, speech recognition starts, matched
//      words turn clay, the judge reacts. Success hands off to
//      UnlockSuccessView, which deep-links back into the unlocked app.

struct UnlockView: View {
    let appConfig: BlockedAppConfig
    let onDismiss: () -> Void

    /// Escalation tier — from how often this app was unlocked in the last
    /// 12 hours. Repeat visits get a longer stare and a colder judge.
    private let tier: MirrorTier

    init(appConfig: BlockedAppConfig, onDismiss: @escaping () -> Void) {
        self.appConfig = appConfig
        self.onDismiss = onDismiss
        let tier = MirrorTier.tier(forRecentUnlocks: appConfig.recentUnlockCount(withinHours: 12))
        self.tier = tier
        _mirrorLine = State(initialValue: tier.lines.randomElement() ?? tier.lines[0])
    }

    @StateObject private var camera = CameraManager()
    @StateObject private var speech = SpeechRecognitionManager()

    @Environment(\.scenePhase) private var scenePhase

    @State private var permissionsGranted = false
    @State private var success = false
    @State private var showMismatch = false

    /// User's brightness before the mirror phase raised it; restored on exit.
    @State private var savedBrightness: CGFloat?

    /// How many phrase words have been matched — drives per-word haptic ticks.
    @State private var lastMatchedWordCount = 0

    /// Mirror sub-line, picked once per appearance so it varies across sessions.
    @State private var mirrorLine: String

    // Mirror phase
    private enum Phase { case mirror, speak }
    @State private var phase: Phase = .mirror
    @State private var mirrorTime: Double = 0
    private let mirrorTick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Camera background
            if permissionsGranted {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            // Subtle dim for legibility — suppressed during the mirror phase:
            // the judge wants you clearly lit, not tastefully shadowed. Fades
            // back in when the phrase card appears.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.40),
                    Color.black.opacity(0.55)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(phase == .mirror && !success ? 0 : 1)

            if success {
                UnlockSuccessView(app: appConfig, onContinue: onDismiss)
                    .transition(.opacity)
            } else {
                switch phase {
                case .mirror: mirrorUI.transition(.opacity)
                case .speak:  playfulUI.transition(.opacity)
                }
            }

            if showMismatch {
                UnlockMismatchOverlay(
                    onRetry: {
                        showMismatch = false
                        speech.startListening(for: appConfig.unlockPhrase)
                    },
                    onClose: {
                        showMismatch = false
                        onDismiss()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: success)
        .animation(.easeOut(duration: 0.35), value: phase)
        .animation(.easeOut(duration: 0.25), value: showMismatch)
        .task { await setup() }
        .onDisappear {
            camera.stop()
            speech.stopListening()
            restoreBrightness()
        }
        .onChange(of: speech.phraseMatched) { matched in
            if matched { handleSuccess() }
        }
        .onChange(of: speech.transcribedText) { _ in
            // Haptic tick each time another phrase word lands.
            let count = matchedWordCount
            if count > lastMatchedWordCount {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            lastMatchedWordCount = count
        }
        .onReceive(mirrorTick) { _ in
            advanceMirror()
        }
        .onChange(of: scenePhase) { newPhase in
            // iOS doesn't revert forced brightness on its own — hand it back
            // whenever we leave the foreground, re-raise if we return mid-mirror.
            switch newPhase {
            case .background:
                restoreBrightness()
            case .active:
                if phase == .mirror, permissionsGranted, !success {
                    raiseBrightness()
                }
            default:
                break
            }
        }
    }

    // MARK: - Mirror phase

    private var mirrorUI: some View {
        VStack(spacing: 0) {
            // Top: close + status pill
            ZStack {
                HStack {
                    closeButton
                    Spacer()
                }
                .padding(.horizontal, 16)

                StatusPill(text: "reflect", active: camera.faceDetected)
            }
            .padding(.top, 50) // clear status bar / dynamic island

            // Notice card sits high — right around where the user's on-screen
            // eyes land at normal holding distance — so reading it keeps them
            // looking at their own face instead of glancing to the bottom.
            VStack(alignment: .leading, spacing: 6) {
                Text(tier.caption)
                    .captionMono()
                    .foregroundStyle(Theme.inkFaint)

                Text(tier.title)
                    .font(.serifItalic(28))
                    .tracking(-0.56)
                    .foregroundStyle(Theme.ink)

                Text(camera.faceDetected || !permissionsGranted
                     ? mirrorLine.replacingOccurrences(of: "{app}",
                                                       with: appConfig.displayName.lowercased())
                     : "the judge can't see your face.")
                    .font(.sans(14))
                    .foregroundStyle(Theme.inkMuted)
                    .lineSpacing(2)

                // Progress — fills only while a face is in frame.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.08))
                        Capsule()
                            .fill(Theme.clay)
                            .frame(width: geo.size.width * min(1, mirrorTime / tier.duration))
                    }
                }
                .frame(height: 3)
                .padding(.top, 10)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(Theme.cream.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Spacer()

            // Judge observes from the bottom corner so nothing covers the face.
            // Mood hardens with each repeat visit — the judge remembers.
            HStack {
                Spacer()
                Mascot(mood: tier.mood, size: 64, paperColor: Theme.cream)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .background(Theme.cream.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                    .padding(.trailing, 20)
                    .padding(.bottom, 28)
            }
        }
    }

    private func advanceMirror() {
        guard phase == .mirror, !success else { return }
        // Without camera permission there's nothing to reflect in — skip the
        // ritual rather than trap the user (speech errors surface in act 2).
        guard permissionsGranted else {
            if mirrorTime > 0 || speech.error != nil { beginSpeakPhase() }
            return
        }
        guard camera.faceDetected else { return }
        mirrorTime += 0.05
        if mirrorTime >= tier.duration {
            beginSpeakPhase()
        }
    }

    private func beginSpeakPhase() {
        guard phase == .mirror else { return }
        phase = .speak
        restoreBrightness()
        // Soft thud: reflection accepted, proceed to begging.
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        speech.startListening(for: appConfig.unlockPhrase)
    }

    // MARK: - Speak phase (playful UI)

    private var playfulUI: some View {
        VStack(spacing: 0) {
            // Top: close + listening pill
            ZStack {
                HStack {
                    closeButton
                    Spacer()
                }
                .padding(.horizontal, 16)

                StatusPill(text: speech.isListening ? "listening" : "paused",
                           active: speech.isListening)
            }
            .padding(.top, 50) // clear status bar / dynamic island

            // Teleprompter: the phrase sits at eye level — same spot the
            // mirror notice occupied — so the user reads it while looking at
            // their own eyes, newscaster-style. Looking down to read was
            // breaking the eye contact that gives the ritual its sting.
            phraseCard
                .padding(.horizontal, 16)
                .padding(.top, 14)

            Spacer()

            // Bottom: slim transcript feedback + the judge, face unobstructed.
            HStack(alignment: .bottom, spacing: 12) {
                transcriptStrip
                judgeCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.4), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(PressScale())
    }

    // MARK: - Judge card (top-right)

    private var judgeCard: some View {
        let frac = matchedFraction
        let mood: MascotMood
        if speech.phraseMatched { mood = .smitten }
        else if frac > 0.6      { mood = .smirk }
        else if frac > 0.05     { mood = .sideeye }
        else                    { mood = .judging }

        return Mascot(
            mood: mood, size: 64,
            listening: speech.isListening,
            paperColor: Theme.cream
        )
        .padding(8)
        .background(.ultraThinMaterial)
        .background(Theme.cream.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
    }

    // MARK: - Phrase card

    private var phraseCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("say to the judge →")
                .captionMono()
                .foregroundStyle(Theme.inkFaint)

            HighlightedPhrase(
                phrase: appConfig.unlockPhrase,
                transcript: speech.transcribedText
            )

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule()
                        .fill(Theme.clay)
                        .frame(width: geo.size.width * matchedFraction)
                        .animation(.easeOut(duration: 0.22), value: matchedFraction)
                }
            }
            .frame(height: 3)
            .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .background(Theme.cream.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }

    /// Slim, glanceable transcript. The phrase card's word-highlighting is the
    /// primary feedback; this exists for "what did it hear?" and errors.
    private var transcriptStrip: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(speech.transcribedText.isEmpty
                 ? "start speaking…"
                 : speech.transcribedText)
                .font(.mono(12))
                .foregroundStyle(speech.transcribedText.isEmpty
                                 ? Color.white.opacity(0.4)
                                 : .white)
                .lineLimit(2)
                .truncationMode(.head)

            if let err = speech.error ?? camera.error {
                Text(err)
                    .font(.mono(11))
                    .foregroundStyle(Theme.pulse.opacity(0.9))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Match progress

    /// Fraction of the target phrase that has been spoken so far (0–1).
    private var matchedFraction: Double {
        let target = appConfig.unlockPhrase.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let said = speech.transcribedText.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return 0 }
        if speech.phraseMatched { return 1 }
        return min(1, Double(said.count) / Double(target.count))
    }

    /// Number of phrase words heard so far — mirrors HighlightedPhrase's logic.
    private var matchedWordCount: Int {
        let said = speech.transcribedText.lowercased()
        return appConfig.unlockPhrase.split(separator: " ").filter { word in
            let stripped = word.lowercased().filter { !".,!?".contains($0) }
            return !stripped.isEmpty && said.contains(stripped)
        }.count
    }

    // MARK: - Setup + success

    private func setup() async {
        permissionsGranted = await SpeechRecognitionManager.requestPermissions()

        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraStatus == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        let cameraOK = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        permissionsGranted = permissionsGranted && cameraOK

        if permissionsGranted {
            camera.start()
            // Nowhere to hide: the mirror gets full backlight. Restored when
            // the mirror ends, the view closes, or the app backgrounds.
            if phase == .mirror { raiseBrightness() }
            // Speech starts when the mirror phase completes (beginSpeakPhase).
        } else {
            // No camera to reflect in — skip straight to the speak phase so
            // its error surface explains what's missing.
            phase = .speak
            speech.startListening(for: appConfig.unlockPhrase)
        }
    }

    private func handleSuccess() {
        success = true
        camera.stop()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AppBlockManager.shared.unlockApp(id: appConfig.id)
    }

    // MARK: - Brightness (mirror phase)

    /// The screen this scene is on. UIScreen.main is deprecated on iOS 16+,
    /// so resolve via the connected window scene with a fallback.
    private static func activeScreen() -> UIScreen {
        (UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen)
            ?? UIScreen.main
    }

    private func raiseBrightness() {
        let screen = Self.activeScreen()
        if savedBrightness == nil { savedBrightness = screen.brightness }
        animateBrightness(to: 1.0)
    }

    private func restoreBrightness() {
        guard let original = savedBrightness else { return }
        savedBrightness = nil
        animateBrightness(to: original)
    }

    /// Step the system brightness over ~0.3s — an instant snap to full is jarring.
    private func animateBrightness(to target: CGFloat) {
        let screen = Self.activeScreen()
        Task { @MainActor in
            let start = screen.brightness
            guard abs(start - target) > 0.01 else {
                screen.brightness = target
                return
            }
            let steps = 14
            for i in 1...steps {
                screen.brightness = start + (target - start) * CGFloat(i) / CGFloat(steps)
                try? await Task.sleep(for: .milliseconds(22))
            }
        }
    }
}

// MARK: - Mirror tiers — the judge remembers
//
// The mirror ritual escalates with repeat unlocks of the same app inside a
// 12-hour window: longer stare, colder judge, copy that knows your history.
// "{app}" in a line is replaced with the app's lowercased display name.

private struct MirrorTier {
    let duration: Double
    let mood: MascotMood
    let caption: String
    let title: String
    let lines: [String]

    static func tier(forRecentUnlocks count: Int) -> MirrorTier {
        switch count {
        case 0:  return first
        case 1:  return second
        default: return third
        }
    }

    /// First visit of the window — the standard ritual.
    static let first = MirrorTier(
        duration: 3.0,
        mood: .flat,
        caption: "before you beg →",
        title: "look at yourself.",
        lines: [
            "take it in. this is the person who wants {app}.",
            "no filter. just consequences.",
            "the judge sees you. now you do too.",
            "hold still. reflect on your choices.",
            "eye contact, please. you owe yourself that much.",
        ]
    )

    /// Second visit — the judge noticed.
    static let second = MirrorTier(
        duration: 4.5,
        mood: .unimpressed,
        caption: "before you beg. again →",
        title: "back already.",
        lines: [
            "that didn't last long.",
            "the judge kept your file open.",
            "second visit. the judge is taking notes.",
            "you said you'd be quick last time too.",
        ]
    )

    /// Third+ visit — disappointment, extended reflection.
    static let third = MirrorTier(
        duration: 6.0,
        mood: .disappointed,
        caption: "before you beg. again. →",
        title: "again.",
        lines: [
            "we both knew you'd be back.",
            "not surprised. just disappointed.",
            "the judge has stopped counting. (they haven't.)",
            "take a longer look this time.",
        ]
    )
}

// MARK: - Status pill (top center)

private struct StatusPill: View {
    let text: String
    let active: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.pulse)
                .frame(width: 8, height: 8)
                .scaleEffect(active ? 1.15 : 1)
                .opacity(active ? 1 : 0.4)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                           value: active)

            Text(text)
                .font(.sans(13, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.4))
        .background(.ultraThinMaterial)
        .clipShape(Capsule(style: .continuous))
    }
}

// MARK: - Highlighted phrase
//
// Renders the target phrase with each spoken word colored clay.
// Matching is permissive: a word is "matched" if the user has spoken any
// word that contains its lowercase, punctuation-stripped form, in order.

private struct HighlightedPhrase: View {
    let phrase: String
    let transcript: String

    var body: some View {
        let words = phrase.split(separator: " ").map(String.init)
        let said = transcript
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        Text(buildAttributed(words: words, said: said))
            .font(.serifItalic(22))
            .tracking(-0.22)
            .lineSpacing(4)
    }

    private func buildAttributed(words: [String], said: String) -> AttributedString {
        var out = AttributedString("\u{201C}")
        out.foregroundColor = Theme.ink
        for (i, w) in words.enumerated() {
            let stripped = w.lowercased().filter { !".,!?".contains($0) }
            let matched = !stripped.isEmpty && said.contains(stripped)
            var part = AttributedString(w + (i < words.count - 1 ? " " : ""))
            part.foregroundColor = matched ? Theme.clayDeep : Theme.ink.opacity(0.5)
            part.font = matched
                ? .serifItalic(22).weight(.medium)
                : .serifItalic(22)
            out.append(part)
        }
        out.append(AttributedString("\u{201D}"))
        return out
    }
}
