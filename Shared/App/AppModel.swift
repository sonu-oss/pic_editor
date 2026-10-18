import AVFoundation
import Foundation
import Observation

/// The single owner of app state. Views read from it; later phases add EditState and EditHistory here.
@MainActor
@Observable
final class AppModel {
    enum CameraState: Equatable {
        case off
        case running
        case denied
        case failed(String)

        var label: String {
            switch self {
            case .off: "Off"
            case .running: "On"
            case .denied: "No permission"
            case .failed: "Error"
            }
        }
    }

    // Camera and tracking
    var cameraState: CameraState = .off
    var hands: [Hand] = []
    var trackingFPS = 0.0

    // Debug switches (move to a Settings window in Phase 5)
    var showSkeleton = true
    var smoothingEnabled = true
    var showCameraPreview = true

    // CAM-5: the camera only runs while the app is in front and the window isn't minimized.
    var isAppActive = true
    var isWindowMinimized = false
    var cameraShouldRun: Bool { isAppActive && !isWindowMinimized }

    let camera: CameraManager
    private let handFrames: AsyncStream<HandFrame>
    @ObservationIgnored private var smoother = HandSmoother()
    @ObservationIgnored private var fpsCounter = FPSCounter()

    init() {
        // Keep only the newest frame if the UI falls behind.
        let (stream, continuation) = AsyncStream.makeStream(of: HandFrame.self, bufferingPolicy: .bufferingNewest(1))
        handFrames = stream
        camera = Self.makeCamera(sendingFramesTo: continuation)
    }

    /// Camera → hand tracker → stream. Built outside the main actor because it runs on the camera's queue.
    private nonisolated static func makeCamera(
        sendingFramesTo continuation: AsyncStream<HandFrame>.Continuation
    ) -> CameraManager {
        let tracker = HandTracker()
        return CameraManager { pixelBuffer, timestamp in
            continuation.yield(tracker.process(pixelBuffer, timestamp: timestamp))
        }
    }

    /// Receives hand frames for as long as the window is open.
    func runHandTracking() async {
        for await frame in handFrames {
            receive(frame)
        }
    }

    func receive(_ frame: HandFrame) {
        trackingFPS = fpsCounter.record(frame.timestamp)
        if smoothingEnabled {
            hands = smoother.smooth(frame).hands
        } else {
            smoother.reset()
            hands = frame.hands
        }
    }

    /// Starts or stops the camera to match `cameraShouldRun`, asking for permission the first time.
    func updateCamera() async {
        guard !Self.isRunningTests else { return }

        guard cameraShouldRun else {
            await camera.stop()
            if cameraState == .running { cameraState = .off }
            hands = []
            trackingFPS = 0
            fpsCounter.reset()
            return
        }

        let allowed = await Self.hasCameraPermission()
        guard !Task.isCancelled else { return }
        guard allowed else {
            cameraState = .denied
            return
        }

        do {
            try await camera.start()
            guard !Task.isCancelled else { return }
            cameraState = .running
        } catch {
            cameraState = .failed(error.localizedDescription)
        }
    }

    private static func hasCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    /// Unit tests launch the app too; don't open the camera for them.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
