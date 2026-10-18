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

    // Photo editing (Phase 4)
    var activeTool: Tool = .exposure
    var editState = EditState()
    var history = EditHistory()
    var photoName: String?
    var previewImage: RenderedImage?
    var zoomScale = 1.0
    var isImporting = false
    var isExportingPhoto = false
    var exportDocument: ImageDocument?
    var hasPhoto: Bool { photoName != nil }

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
    @ObservationIgnored private var stateBeforeAdjust: EditState?
    @ObservationIgnored private let renderer = RenderPipeline()
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var renderPending = false
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
        poseDiagnostics = (gestures.trackedHand.map { diagnosticsClassifier.diagnostics(for: $0) } ?? "no hand")
            + String(format: "\nswipe speed %+.2f (needs ±%.2f)", gestures.stateMachine.wristSpeedX, gestures.config.swipeVelocity)
        armProgress = gestures.stateMachine.armProgress
        trackedHand = gestures.trackedHand
        for command in commands {
            apply(command)
        }
    }

    func value(of tool: Tool) -> Double {
        editState[tool]
    }

    /// Carries out one command, from a gesture or the keyboard.
    func apply(_ command: EditCommand) {
        switch command {
        case .arm:
            lastAction = "Armed"
        case .disarm:
            lastAction = "Disarmed"
        case .beginAdjust:
            stateBeforeAdjust = editState
            lastAction = "Adjusting \(activeTool.displayName)"
        case .adjust(let delta):
            editState[activeTool] = value(of: activeTool) + delta * activeTool.span
            requestRender()
        case .endAdjust:
            // HI-2: one pinch is one undo step.
            if let before = stateBeforeAdjust, before != editState {
                history.record(before)
            }
            stateBeforeAdjust = nil
            lastAction = "Set \(activeTool.displayName)"
        case .cancelAdjust:
            if let before = stateBeforeAdjust {
                editState = before
                requestRender()
            }
            stateBeforeAdjust = nil
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
            if let previous = history.undo(from: editState) {
                editState = previous
                requestRender()
                lastAction = "Undo"
            } else {
                lastAction = "Nothing to undo"
            }
        case .redo:
            if let next = history.redo(from: editState) {
                editState = next
                requestRender()
                lastAction = "Redo"
            } else {
                lastAction = "Nothing to redo"
            }
        case .export:
            startExport()
        case .zoom(let factor):
            zoomScale = min(max(zoomScale * factor, 1), 8)
        }
    }

    /// HI-3: applying a preset is one undo step.
    func applyPreset(_ preset: Preset) {
        guard preset != editState.preset else { return }
        let before = editState
        editState.preset = preset
        history.record(before)
        requestRender()
        lastAction = "Preset: \(preset.displayName)"
    }

    // MARK: - Photo

    /// IO-1: opens a JPEG, PNG or HEIC and starts a fresh edit.
    func openPhoto(_ url: URL) async {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        do {
            _ = try await renderer.load(url)
            photoName = url.deletingPathExtension().lastPathComponent
            editState = EditState()
            history = EditHistory()
            zoomScale = 1
            previewImage = nil
            requestRender()
            lastAction = "Opened \(url.lastPathComponent)"
        } catch {
            lastAction = error.localizedDescription
        }
    }

    /// ED-5: renders off the main thread; while one render runs, only the newest state waits.
    func requestRender() {
        guard hasPhoto else { return }
        if renderTask != nil {
            renderPending = true
            return
        }
        renderTask = Task {
            await self.renderLoop()
        }
    }

    private func renderLoop() async {
        repeat {
            renderPending = false
            if let image = await renderer.renderPreview(editState) {
                previewImage = image
            }
        } while renderPending
        renderTask = nil
    }

    /// IO-2/IO-3: renders full size, then asks where to save. The original is never touched.
    func startExport() {
        guard hasPhoto else {
            lastAction = "Open a photo first"
            return
        }
        lastAction = "Exporting…"
        let state = editState
        Task {
            do {
                let data = try await self.renderer.exportJPEG(state)
                self.exportDocument = ImageDocument(data: data)
                self.isExportingPhoto = true
                self.lastAction = "Export ready"
            } catch {
                self.lastAction = error.localizedDescription
            }
        }
    }

    var exportFilename: String {
        "\(photoName ?? "photo")-edited"
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
