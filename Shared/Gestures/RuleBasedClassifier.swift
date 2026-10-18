import Foundation

/// Names a hand pose with simple geometry rules (PRD Section 4, "Detection rules").
struct RuleBasedClassifier: GestureClassifier {
    var config: GestureConfig

    init(config: GestureConfig = GestureConfig()) {
        self.config = config
    }

    func classify(_ hand: Hand, previous: HandPose) -> HandPose {
        // Keep only joints Vision is reasonably sure about, with x stretched to real proportions.
        var points: [JointName: Vector2] = [:]
        for (name, joint) in hand.joints where joint.confidence >= config.minimumJointConfidence {
            points[name] = Vector2(x: joint.x * config.aspectRatio, y: joint.y)
        }
        guard points.count >= config.minimumConfidentJoints,
              let wrist = points[.wrist],
              let middleBase = points[.middleMCP]
        else { return .none }

        let handSize = wrist.distance(to: middleBase)
        guard handSize > 0 else { return .none }

        if isPinch(points, wrist: wrist, handSize: handSize, wasPinching: previous == .pinch) {
            return .pinch
        }

        guard let thumb = thumbExtended(points, handSize: handSize),
              let index = fingerExtended(points, wrist: wrist, knuckle: .indexPIP, tip: .indexTip),
              let middle = fingerExtended(points, wrist: wrist, knuckle: .middlePIP, tip: .middleTip),
              let ring = fingerExtended(points, wrist: wrist, knuckle: .ringPIP, tip: .ringTip),
              let little = fingerExtended(points, wrist: wrist, knuckle: .littlePIP, tip: .littleTip)
        else { return .none }

        // The thumb is ignored for point and peace: people hold it either way.
        switch (thumb, index, middle, ring, little) {
        case (true, true, true, true, true):
            return .openPalm
        case (_, true, false, false, false):
            return .point
        case (_, true, true, false, false):
            return .peace
        case (true, false, false, false, false):
            // y grows downward, so "above the wrist" means a smaller y.
            guard let thumbTip = points[.thumbTip], thumbTip.y < wrist.y else { return .none }
            return .thumbsUp
        case (false, false, false, false, false):
            return .fist
        default:
            return .none
        }
    }

    /// A one-line readout of the numbers behind the decision, for the debug panel.
    /// Each finger shows its reach ratio (straight above `fingerExtendedRatio`), thumb its spread
    /// (straight above `thumbExtendedRatio`), "?" when a joint is missing or too uncertain.
    func diagnostics(for hand: Hand) -> String {
        var points: [JointName: Vector2] = [:]
        for (name, joint) in hand.joints where joint.confidence >= config.minimumJointConfidence {
            points[name] = Vector2(x: joint.x * config.aspectRatio, y: joint.y)
        }
        let header = "joints \(points.count)/\(hand.joints.count)"
        guard let wrist = points[.wrist], let middleBase = points[.middleMCP] else {
            return header + ", no wrist or middle knuckle"
        }
        let handSize = wrist.distance(to: middleBase)
        guard handSize > 0 else { return header }

        func fmt(_ value: Double?) -> String {
            guard let value else { return "?" }
            return String(format: "%.2f", value)
        }
        func reach(_ knuckle: JointName, _ tip: JointName) -> Double? {
            guard let k = points[knuckle], let t = points[tip], wrist.distance(to: k) > 0 else { return nil }
            return wrist.distance(to: t) / wrist.distance(to: k)
        }
        var thumb: Double?
        if let tip = points[.thumbTip], let base = points[.indexMCP] {
            thumb = tip.distance(to: base) / handSize
        }
        var pinchGap: Double?
        if let a = points[.thumbTip], let b = points[.indexTip] {
            pinchGap = a.distance(to: b) / handSize
        }
        return header
            + "\nT \(fmt(thumb))  I \(fmt(reach(.indexPIP, .indexTip)))  M \(fmt(reach(.middlePIP, .middleTip)))"
            + "  R \(fmt(reach(.ringPIP, .ringTip)))  L \(fmt(reach(.littlePIP, .littleTip)))"
            + "\npinch gap \(fmt(pinchGap))"
    }

    private func isPinch(_ points: [JointName: Vector2], wrist: Vector2, handSize: Double, wasPinching: Bool) -> Bool {
        guard let thumbTip = points[.thumbTip],
              let indexTip = points[.indexTip],
              let indexKnuckle = points[.indexPIP]
        else { return false }
        let knuckleDistance = wrist.distance(to: indexKnuckle)
        guard knuckleDistance > 0 else { return false }

        let gap = thumbTip.distance(to: indexTip) / handSize
        let threshold = wasPinching ? config.pinchExitRatio : config.pinchEnterRatio
        let reach = wrist.distance(to: indexTip) / knuckleDistance
        return gap < threshold && reach >= config.pinchMinimumIndexReach
    }

    /// nil when the joints needed to decide aren't visible.
    private func fingerExtended(_ points: [JointName: Vector2], wrist: Vector2, knuckle: JointName, tip: JointName) -> Bool? {
        guard let knucklePoint = points[knuckle], let tipPoint = points[tip] else { return nil }
        return wrist.distance(to: tipPoint) > config.fingerExtendedRatio * wrist.distance(to: knucklePoint)
    }

    private func thumbExtended(_ points: [JointName: Vector2], handSize: Double) -> Bool? {
        guard let thumbTip = points[.thumbTip], let indexBase = points[.indexMCP] else { return nil }
        return thumbTip.distance(to: indexBase) > config.thumbExtendedRatio * handSize
    }
}
