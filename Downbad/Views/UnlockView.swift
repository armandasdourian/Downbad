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

    @StateObject private var camera = CameraManager()
    @StateObject private var speech = SpeechRecognitionManager()

    @Environment(\.scenePhase) private var scenePhase

    @State private var permissionsGranted = false
    @State private var success = false
    @State private var showMismatch = false

    /// User's brightness before the mirror phase raised it; restored on exit.
    @State private var savedBrightness: CGFloat?

    // Mirror phase
    private enum Phase { case mirror, speak }
    @State private var phase: Phase = .mirror
    @State private var mirrorTime: Double = 0
    private let mirrorDuration: Double = 3.0
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
                Text("before you beg →")
                    .captionMono()
                    .foregroundStyle(Theme.inkFaint)

                Text("look at yourself.")
                    .font(.serifItalic(28))
                    .tracking(-0.56)
                    .foregroundStyle(Theme.ink)

                Text(camera.faceDetected || !permissionsGranted
                     ? "take it in. this is the person who wants \(appConfig.displayName.lowercased())."
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
                            .frame(width: geo.size.width * min(1, mirrorTime / mirrorDuration))
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
            HStack {
                Spacer()
                Mascot(mood: .flat, size: 64, paperColor: Theme.cream)
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
        if mirrorTime >= mirrorDuration {
            beginSpeakPhase()
        }
    }

    private func beginSpeakPhase() {
        guard phase == .mirror else { return }
        phase = .speak
        restoreBrightness()
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

            // Judge peeking
            HStack {
                Spacer()
                judgeCard
                    .padding(.trailing, 20)
                    .padding(.top, 16)
            }

            Spacer()

            // Phrase card + transcript
            VStack(spacing: 16) {
                phraseCard
                transcriptCard
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

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("you said")
                .font(.mono(11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.88)

            HStack(alignment: .firstTextBaseline) {
                Text(speech.transcribedText.isEmpty
                     ? "start speaking…"
                     : speech.transcribedText)
                    .font(.mono(14))
                    .foregroundStyle(speech.transcribedText.isEmpty
                                     ? Color.white.opacity(0.4)
                                     : .white)
                    .lineSpacing(2)
                Spacer(minLength: 0)
            }

            if let err = speech.error ?? camera.error {
                Text(err)
                    .font(.mono(11))
                    .foregroundStyle(Theme.pulse.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
