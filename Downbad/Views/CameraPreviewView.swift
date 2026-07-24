import SwiftUI
import AVFoundation
import Vision

/// UIViewRepresentable that shows a live camera preview.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

/// Manages the camera session lifecycle and runs lightweight face detection
/// on the feed so the unlock flow's "look at yourself" phase can require an
/// actual face in frame before its timer advances.
final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var isRunning = false
    @Published var error: String?

    /// True while a face is visible in the front camera. Updated ~3x/sec.
    @Published var faceDetected = false

    private let videoOutput = AVCaptureVideoDataOutput()
    private let detectionQueue = DispatchQueue(label: "com.voicegate.downbad.face-detection")
    private var lastDetectionAt = Date.distantPast

    func start() {
        guard !isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = "Could not access front camera."
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Sample the feed for face presence. Preview quality is unaffected;
        // detection is throttled inside the delegate.
        if session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: detectionQueue)
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()

        Task.detached(priority: .userInitiated) { [session] in
            session.startRunning()
            await MainActor.run { self.isRunning = true }
        }
    }

    func stop() {
        guard isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.stopRunning()
            await MainActor.run {
                self.isRunning = false
                self.faceDetected = false
            }
        }
    }
}

// MARK: - Face detection

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // ~3 detections per second is plenty for a "hold still" gate and keeps
        // Vision work off the battery budget.
        let now = Date()
        guard now.timeIntervalSince(lastDetectionAt) > 0.3 else { return }
        lastDetectionAt = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            let hasFace = (request.results as? [VNFaceObservation])?.isEmpty == false
            DispatchQueue.main.async {
                if self?.faceDetected != hasFace {
                    self?.faceDetected = hasFace
                }
            }
        }

        // Front camera in portrait delivers .leftMirrored-oriented buffers.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
        try? handler.perform([request])
    }
}
