import Foundation
import Speech
import AVFoundation

/// Handles on-device speech recognition and phrase matching.
@MainActor
final class SpeechRecognitionManager: ObservableObject {
    @Published var transcribedText = ""
    @Published var isListening = false
    @Published var phraseMatched = false
    @Published var error: String?

    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var targetPhrase: String = ""

    // MARK: - Permissions

    static func requestPermissions() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let micAuthorized: Bool
        if #available(iOS 17, *) {
            micAuthorized = await AVAudioApplication.requestRecordPermission()
        } else {
            micAuthorized = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        return speechAuthorized && micAuthorized
    }

    // MARK: - Recognition

    func startListening(for phrase: String) {
        targetPhrase = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        transcribedText = ""
        phraseMatched = false
        error = nil

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognition is not available on this device."
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }

            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = true

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let result {
                        self.transcribedText = result.bestTranscription.formattedString
                        self.checkMatch()
                    }

                    if let error {
                        self.error = error.localizedDescription
                        self.stopListening()
                    }
                }
            }

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            self.error = "Failed to start audio: \(error.localizedDescription)"
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    // MARK: - Matching

    private func checkMatch() {
        let spoken = transcribedText
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if spoken.contains(targetPhrase) {
            phraseMatched = true
            stopListening()
        }
    }
}
