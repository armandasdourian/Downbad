import SwiftUI
import AVFoundation

struct UnlockView: View {
    let appConfig: BlockedAppConfig
    let onDismiss: () -> Void

    @StateObject private var camera = CameraManager()
    @StateObject private var speech = SpeechRecognitionManager()
    @State private var permissionsGranted = false
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            // Camera preview fills the background
            if permissionsGranted {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            // Dark overlay for readability
            Color.black.opacity(0.5).ignoresSafeArea()

            if showSuccess {
                successOverlay
            } else {
                unlockInterface
            }
        }
        .task {
            await setup()
        }
        .onDisappear {
            camera.stop()
            speech.stopListening()
        }
        .onChange(of: speech.phraseMatched) { matched in
            if matched {
                handleSuccess()
            }
        }
    }

    // MARK: - Unlock Interface

    private var unlockInterface: some View {
        VStack(spacing: 32) {
            // Close button
            HStack {
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding()
            }

            Spacer()

            // App name
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)

                Text(appConfig.displayName)
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("is locked")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
            }

            // Phrase to say
            VStack(spacing: 12) {
                Text("Say this to unlock:")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Text("\"\(appConfig.unlockPhrase)\"")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            // Live transcription
            VStack(spacing: 8) {
                if speech.isListening {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)

                        Text("Listening...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Text(speech.transcribedText.isEmpty ? "Start speaking..." : speech.transcribedText)
                    .font(.body)
                    .foregroundStyle(speech.transcribedText.isEmpty ? .white.opacity(0.4) : .white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .frame(minHeight: 60)
                    .animation(.easeInOut, value: speech.transcribedText)
            }

            // Error display
            if let error = speech.error ?? camera.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            // Retry button
            if !speech.isListening && !speech.phraseMatched {
                Button("Try Again") {
                    speech.startListening(for: appConfig.unlockPhrase)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.3))
            }

            Spacer()

            // Duration info
            Text("Unlocks for \(appConfig.unlockDuration.displayName)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 32)
        }
    }

    // MARK: - Success

    private var successOverlay: some View {
        VStack(spacing: 24) {
            if #available(iOS 17.0, *) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showSuccess)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
            }

            Text("\(appConfig.displayName) Unlocked!")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("For \(appConfig.unlockDuration.displayName)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Logic

    private func setup() async {
        permissionsGranted = await SpeechRecognitionManager.requestPermissions()

        // Camera permission
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraStatus == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .video)
        }

        if permissionsGranted {
            camera.start()
            speech.startListening(for: appConfig.unlockPhrase)
        }
    }

    private func handleSuccess() {
        showSuccess = true
        camera.stop()

        AppBlockManager.shared.unlockApp(id: appConfig.id)

        // Dismiss after a short delay
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            onDismiss()
        }
    }
}
