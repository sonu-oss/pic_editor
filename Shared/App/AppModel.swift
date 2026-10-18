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

    // Gestures (Phase 3)
    var gestureState: GestureState = .idle
    var pose: HandPose = .none
    var rawPose: HandPose = .none
    var poseDiagnostics = ""
    var armProgress = 0.0
    var trackedHand: Hand?
    var lastAction = "None yet"

    // Tool values. Phase 4 replaces these with EditState and a real photo.
    var activeTool: Tool = .exposure
    var toolValues: [Tool: Double] = Dictionary(uniqueKeysWithValues: Tool.allCases.map { ($0, $0.defaultValue) })

    // Gesture recording (record/replay for tests)
    var isRecording = false
    var isSavingRecording = false
    var recordingDocument: HandSessionDocument?

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
    @ObservationIgnored private var gestures = GesturePipeline()
    @ObservationIgnored private let diagnosticsClassifier = RuleBasedClassifier()
    @ObservationIgnored private var valueBeforeAdjust: Double?
    @ObservationIgnored private var recordedFrames: [HandFrame] = []

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
        let shown: HandFrame
        if smoothingEnabled {
            shown = smoother.smooth(frame)
        } else {
            smoother.reset()
            shown = frame
        }
        hands = shown.hands
        if isRecording {
            recordedFrames.append(shown)
        }

        let commands = gestures.process(shown)
        gestureState = gestures.stateMachine.state
        pose = gestures.stablePose
        rawPose = gestures.rawPose
        poseDiagnostics = gestures.trackedHand.map { diagnosticsClassifier.diagnostics(for: $0) } ?? "no hand"
        armProgress = gestures.stateMachine.armProgress
        trackedHand = gestures.trackedHand
        for command in commands {
            apply(command)
        }
    }

    func value(of tool: Tool) -> Double {
        toolValues[tool] ?? tool.defaultValue
    }

    /// Carries out one command. For now most only show up as "last action"; Phase 4 makes them edit the photo.
    func apply(_ command: EditCommand) {
        switch command {
        case .arm:
            lastAction = "Armed"
        case .disarm:
            lastAction = "Disarmed"
        case .beginAdjust:
            valueBeforeAdjust = value(of: activeTool)
            lastAction = "Adjusting \(activeTool.displayName)"
        case .adjust(let delta):
            toolValues[activeTool] = activeTool.clamped(value(of: activeTool) + delta * activeTool.span)
        case .endAdjust:
            valueBeforeAdjust = nil
            lastAction = "Set \(activeTool.displayName)"
        case .cancelAdjust:
            if let original = valueBeforeAdjust {
                toolValues[activeTool] = original
            }
            valueBeforeAdjust = nil
            lastAction = "Cancelled"
        case .nextTool:
            activeTool = activeTool.next
            lastAction = "Next tool"
        case .previousTool:
            activeTool = activeTool.previous
            lastAction = "Previous tool"
        case .cursor:
            break
        case .click:
            lastAction = "Click"
        case .undo:
            lastAction = "Undo"
        case .redo:
            lastAction = "Redo"
        case .export:
            lastAction = "Export"
        case .zoom:
            break
        }
    }

    // MARK: - Recording

    func toggleRecording() {
        if isRecording {
            isRecording = false
            recordingDocument = HandSessionDocument(session: HandSession(frames: recordedFrames))
            recordedFrames = []
            isSavingRecording = true
        } else {
            recordedFrames = []
            isRecording = true
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
            gestures = GesturePipeline()
            gestureState = .idle
            pose = .none
            rawPose = .none
            armProgress = 0
            trackedHand = nil
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
