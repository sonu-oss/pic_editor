/// The four gesture states (GE-4). Nothing edits the photo unless editing is armed first.
enum GestureState: String, Sendable {
    case idle, armed, adjusting, pointing

    var displayName: String {
        switch self {
        case .idle: "Idle"
        case .armed: "Armed"
        case .adjusting: "Adjusting"
        case .pointing: "Pointing"
        }
    }
}

/// One frame's worth of input to the state machine.
struct GestureInput: Sendable {
    var timestamp: Double
    /// The stable (voted) pose.
    var pose: HandPose
    /// The hand being tracked, or nil when no hand is in view.
    var hand: Hand?
}

/// Turns poses over time into editing commands (GE-4, PRD Section 4).
/// Pure Swift with no frameworks, so every rule can be unit-tested without a camera.
///
/// - Idle: hold an open palm for `armHoldDuration` → `.arm`.
/// - Armed: pinch → adjusting; point → pointing; fast palm swipe → next/previous tool;
///   peace → undo (once per gesture); thumbs up held → export; fist → disarm.
/// - Adjusting: moving the pinch up/down sends `.adjust`; fist cancels; letting go ends.
/// - Pointing: sends the cursor position; holding still for `dwellDuration` → `.click`.
/// - Any non-idle state: no hand for `autoDisarmDelay` → disarm.
struct GestureStateMachine: Sendable {
    var config: GestureConfig

    private(set) var state: GestureState = .idle
    /// 0…1 while an open palm is being held to arm (UI-3).
    private(set) var armProgress = 0.0
    /// 0…1 while pointing still, before a click (UI-4).
    private(set) var dwellProgress = 0.0
    /// 0…1 while thumbs up is held, before export.
    private(set) var exportProgress = 0.0

    private var lastHandSeen: Double?
    private var palmHoldStart: Double?
    private var wristMotion = MotionTracker()
    private var swipeDirection = 0
    private var swipeStreak = 0
    private var lastSwipe = -Double.infinity
    private var pinchStart: Double?
    private var lastPinchY: Double?
    private var undoLatched = false
    private var fistLatched = false
    private var exportStart: Double?
    private var exportLatched = false
    private var dwellAnchor: Vector2?
    private var dwellStart: Double?
    private var dwellLatched = false

    init(config: GestureConfig = GestureConfig()) {
        self.config = config
    }

    mutating func consume(_ input: GestureInput) -> [EditCommand] {
        var commands: [EditCommand] = []
        let time = input.timestamp

        var wristVelocity = Vector2.zero
        if let wrist = input.hand?.joints[.wrist] {
            lastHandSeen = time
            wristVelocity = wristMotion.update(wrist.position, at: time)
        } else {
            wristMotion.reset()
        }

        // Safety: disarm when the hand has been gone for a while.
        if state != .idle, input.hand == nil, let seen = lastHandSeen, time - seen >= config.autoDisarmDelay {
            if state == .adjusting { commands.append(.endAdjust) }
            commands.append(.disarm)
            enterIdle()
            return commands
        }

        switch state {
        case .idle:
            handleIdle(input, &commands)
        case .armed:
            handleArmed(input, wristVelocity: wristVelocity, &commands)
        case .adjusting:
            handleAdjusting(input, &commands)
        case .pointing:
            handlePointing(input, &commands)
        }

        // A gesture triggers once; the hand must leave the pose before it can trigger again.
        if input.pose != .peace { undoLatched = false }
        if input.pose != .fist { fistLatched = false }
        if input.pose != .thumbsUp {
            exportStart = nil
            exportLatched = false
            exportProgress = 0
        }
        return commands
    }

    // MARK: - States

    private mutating func handleIdle(_ input: GestureInput, _ commands: inout [EditCommand]) {
        guard input.pose == .openPalm, input.hand != nil else {
            palmHoldStart = nil
            armProgress = 0
            return
        }
        let start = palmHoldStart ?? input.timestamp
        palmHoldStart = start
        let held = input.timestamp - start
        armProgress = min(held / config.armHoldDuration, 1)
        if held >= config.armHoldDuration {
            commands.append(.arm)
            state = .armed
            armProgress = 0
            palmHoldStart = nil
            // The palm is still up right after arming; don't let it swipe straight away.
            lastSwipe = input.timestamp
        }
    }

    private mutating func handleArmed(_ input: GestureInput, wristVelocity: Vector2, _ commands: inout [EditCommand]) {
        let time = input.timestamp
        if input.pose != .openPalm { swipeStreak = 0 }

        switch input.pose {
        case .fist:
            guard !fistLatched else { return }
            commands.append(.disarm)
            enterIdle()

        case .pinch:
            guard input.hand != nil else { return }
            commands.append(.beginAdjust)
            state = .adjusting
            pinchStart = time
            lastPinchY = nil

        case .point:
            guard input.hand != nil else { return }
            state = .pointing
            resetDwell()
            handlePointing(input, &commands)

        case .peace:
            guard !undoLatched, input.hand != nil else { return }
            commands.append(.undo)
            undoLatched = true

        case .thumbsUp:
            guard !exportLatched, input.hand != nil else { return }
            let start = exportStart ?? time
            exportStart = start
            exportProgress = min((time - start) / config.exportHoldDuration, 1)
            if time - start >= config.exportHoldDuration {
                commands.append(.export)
                exportLatched = true
                exportProgress = 0
            }

        case .openPalm:
            detectSwipe(velocity: wristVelocity.x, at: time, &commands)

        case .none:
            break
        }
    }

    private mutating func handleAdjusting(_ input: GestureInput, _ commands: inout [EditCommand]) {
        guard let hand = input.hand else {
            // Hand lost mid-pinch: keep the value where it is.
            commands.append(.endAdjust)
            state = .armed
            return
        }
        switch input.pose {
        case .pinch:
            guard let start = pinchStart, input.timestamp - start >= config.pinchSettleDuration,
                  let thumbTip = hand.joints[.thumbTip], let indexTip = hand.joints[.indexTip]
            else { return }
            let y = Vector2.midpoint(thumbTip.position, indexTip.position).y
            if let lastY = lastPinchY, y != lastY {
                // Up on screen is a smaller y, and should raise the value.
                commands.append(.adjust(delta: -(y - lastY)))
            }
            lastPinchY = y
        case .fist:
            commands.append(.cancelAdjust)
            state = .armed
            fistLatched = true
        default:
            commands.append(.endAdjust)
            state = .armed
        }
    }

    private mutating func handlePointing(_ input: GestureInput, _ commands: inout [EditCommand]) {
        guard input.pose == .point, let tip = input.hand?.joints[.indexTip] else {
            state = .armed
            resetDwell()
            return
        }
        let point = tip.position
        commands.append(.cursor(x: point.x, y: point.y))

        let stretched = Vector2(x: point.x * config.aspectRatio, y: point.y)
        if let anchor = dwellAnchor, let start = dwellStart, anchor.distance(to: stretched) <= config.dwellRadius {
            guard !dwellLatched else { return }
            let progress = (input.timestamp - start) / config.dwellDuration
            if progress >= 1 {
                commands.append(.click)
                dwellLatched = true
                dwellProgress = 0
            } else {
                dwellProgress = progress
            }
        } else {
            dwellAnchor = stretched
            dwellStart = input.timestamp
            dwellLatched = false
            dwellProgress = 0
        }
    }

    // MARK: - Helpers

    private mutating func detectSwipe(velocity: Double, at time: Double, _ commands: inout [EditCommand]) {
        guard abs(velocity) > config.swipeVelocity else {
            swipeStreak = 0
            return
        }
        let direction = velocity > 0 ? 1 : -1
        if direction == swipeDirection {
            swipeStreak += 1
        } else {
            swipeDirection = direction
            swipeStreak = 1
        }
        guard swipeStreak >= config.swipeMinimumFrames, time - lastSwipe >= config.swipeCooldown else { return }
        // x grows to the right on screen (the picture is mirrored), so right = next tool.
        commands.append(direction > 0 ? .nextTool : .previousTool)
        lastSwipe = time
        swipeStreak = 0
    }

    private mutating func resetDwell() {
        dwellAnchor = nil
        dwellStart = nil
        dwellLatched = false
        dwellProgress = 0
    }

    private mutating func enterIdle() {
        state = .idle
        armProgress = 0
        exportProgress = 0
        palmHoldStart = nil
        pinchStart = nil
        lastPinchY = nil
        swipeStreak = 0
        resetDwell()
    }
}
