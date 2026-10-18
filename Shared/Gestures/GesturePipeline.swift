/// Hand frame in, edit commands out: picks the main hand, names its pose,
/// votes out flicker, then runs the state machine.
struct GesturePipeline: Sendable {
    let config: GestureConfig
    private let classifier: any GestureClassifier
    private var stabilizer: PoseStabilizer
    private(set) var stateMachine: GestureStateMachine
    /// This frame's pose before voting.
    private(set) var rawPose: HandPose = .none
    /// The hand gestures are read from (the biggest, so usually the closest).
    private(set) var trackedHand: Hand?

    var stablePose: HandPose { stabilizer.stablePose }

    init(config: GestureConfig = GestureConfig(), classifier: (any GestureClassifier)? = nil) {
        self.config = config
        self.classifier = classifier ?? RuleBasedClassifier(config: config)
        stabilizer = PoseStabilizer(window: config.stableWindow, votes: config.stableVotes)
        stateMachine = GestureStateMachine(config: config)
    }

    mutating func process(_ frame: HandFrame) -> [EditCommand] {
        let hand = frame.hands.max { handSize($0) < handSize($1) }
        trackedHand = hand
        if let hand {
            rawPose = classifier.classify(hand, previous: rawPose)
        } else {
            rawPose = .none
        }
        let pose = stabilizer.add(rawPose)
        return stateMachine.consume(GestureInput(timestamp: frame.timestamp, pose: pose, hand: hand))
    }

    private func handSize(_ hand: Hand) -> Double {
        guard let wrist = hand.joints[.wrist], let middleBase = hand.joints[.middleMCP] else { return 0 }
        let a = Vector2(x: wrist.x * config.aspectRatio, y: wrist.y)
        let b = Vector2(x: middleBase.x * config.aspectRatio, y: middleBase.y)
        return a.distance(to: b)
    }
}
