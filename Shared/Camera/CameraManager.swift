import AVFoundation
import CoreMedia
import CoreVideo

enum CameraError: LocalizedError, Sendable {
    case noCamera
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noCamera: "No camera was found on this Mac."
        case .cannotAddInput: "The camera couldn't be opened. Another app may be using it."
        case .cannotAddOutput: "The camera couldn't deliver video frames."
        }
    }
}

/// Owns the camera session (CAM-1…3).
///
/// Starting and stopping happen on `sessionQueue`; frames arrive on `videoQueue` and are
/// handed straight to `frameHandler`. Nothing here touches the UI.
/// Marked @unchecked Sendable because its mutable state is only touched on those two serial queues.
final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// The preview window shows this session.
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "GestureEdit.camera.session")
    private let videoQueue = DispatchQueue(label: "GestureEdit.camera.video", qos: .userInteractive)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameHandler: @Sendable (CVPixelBuffer, TimeInterval) -> Void
    private var isConfigured = false

    /// `frameHandler` is called on the video queue for every frame the camera delivers.
    init(frameHandler: @escaping @Sendable (CVPixelBuffer, TimeInterval) -> Void) {
        self.frameHandler = frameHandler
        super.init()
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            sessionQueue.async {
                do {
                    try self.configureIfNeeded()
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if self.session.isRunning {
                    self.session.stopRunning()
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Setup (runs on sessionQueue)

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }
        guard let device = Self.builtInCamera() else { throw CameraError.noCamera }
        let input = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // CAM-2: 1280×720, BGRA frames.
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        // CAM-3: never queue up old frames, so tracking stays in sync with reality.
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput) else { throw CameraError.cannotAddOutput }
        session.addOutput(videoOutput)

        Self.lockFrameRate(of: device, to: 30)
        isConfigured = true
    }

    /// CAM-1: prefer the Mac's own FaceTime camera over an iPhone (Continuity Camera).
    private static func builtInCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first ?? AVCaptureDevice.default(for: .video)
    }

    private static func lockFrameRate(of device: AVCaptureDevice, to fps: Double) {
        let supported = device.activeFormat.videoSupportedFrameRateRanges.contains {
            $0.minFrameRate <= fps && fps <= $0.maxFrameRate
        }
        guard supported, (try? device.lockForConfiguration()) != nil else { return }
        let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        device.unlockForConfiguration()
    }

    // MARK: - Frames (runs on videoQueue)

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        frameHandler(pixelBuffer, timestamp)
    }
}
