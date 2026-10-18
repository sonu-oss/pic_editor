import Foundation
@testable import GestureEdit

/// Hand-made hands for tests. Coordinates are 0…1 with the origin top-left, wrist at the bottom.
enum HandFixtures {
    /// Same as the app's config but with square coordinates, so fixture distances are easy to reason about.
    static let config: GestureConfig = {
        var config = GestureConfig()
        config.aspectRatio = 1
        return config
    }()

    static func hand(for pose: HandPose, offset: Vector2 = .zero, confidence: Double = 1) -> Hand {
        switch pose {
        case .openPalm: hand(thumb: true, index: true, middle: true, ring: true, little: true, offset: offset, confidence: confidence)
        case .point: hand(thumb: false, index: true, middle: false, ring: false, little: false, offset: offset, confidence: confidence)
        case .peace: hand(thumb: false, index: true, middle: true, ring: false, little: false, offset: offset, confidence: confidence)
        case .thumbsUp: hand(thumb: true, index: false, middle: false, ring: false, little: false, offset: offset, confidence: confidence)
        case .fist: hand(thumb: false, index: false, middle: false, ring: false, little: false, offset: offset, confidence: confidence)
        case .pinch: pinch(gap: 0, offset: offset, confidence: confidence)
        case .none: hand(thumb: false, index: false, middle: true, ring: true, little: true, offset: offset, confidence: confidence)
        }
    }

    static func hand(
        thumb: Bool, index: Bool, middle: Bool, ring: Bool, little: Bool,
        offset: Vector2 = .zero, confidence: Double = 1
    ) -> Hand {
        var points: [JointName: Vector2] = [
            .wrist: Vector2(x: 0.5, y: 0.8),
            .thumbCMC: Vector2(x: 0.42, y: 0.75),
            .thumbMP: Vector2(x: 0.38, y: 0.68),
            .thumbIP: Vector2(x: 0.35, y: 0.62),
            .thumbTip: thumb ? Vector2(x: 0.30, y: 0.55) : Vector2(x: 0.46, y: 0.62),
        ]
        addFinger(&points, x: 0.44, extended: index, joints: [.indexMCP, .indexPIP, .indexDIP, .indexTip])
        addFinger(&points, x: 0.50, extended: middle, joints: [.middleMCP, .middlePIP, .middleDIP, .middleTip])
        addFinger(&points, x: 0.56, extended: ring, joints: [.ringMCP, .ringPIP, .ringDIP, .ringTip])
        addFinger(&points, x: 0.62, extended: little, joints: [.littleMCP, .littlePIP, .littleDIP, .littleTip])
        return makeHand(points, offset: offset, confidence: confidence)
    }

    /// Thumb tip touching (gap 0) or near the index tip; other fingers extended like an "OK" sign.
    static func pinch(gap: Double, offset: Vector2 = .zero, confidence: Double = 1) -> Hand {
        var points: [JointName: Vector2] = [
            .wrist: Vector2(x: 0.5, y: 0.8),
            .thumbCMC: Vector2(x: 0.42, y: 0.75),
            .thumbMP: Vector2(x: 0.38, y: 0.68),
            .thumbIP: Vector2(x: 0.38, y: 0.58),
            .thumbTip: Vector2(x: 0.40, y: 0.45 + gap),
            .indexMCP: Vector2(x: 0.44, y: 0.6),
            .indexPIP: Vector2(x: 0.44, y: 0.5),
            .indexDIP: Vector2(x: 0.42, y: 0.47),
            .indexTip: Vector2(x: 0.40, y: 0.45),
        ]
        addFinger(&points, x: 0.50, extended: true, joints: [.middleMCP, .middlePIP, .middleDIP, .middleTip])
        addFinger(&points, x: 0.56, extended: true, joints: [.ringMCP, .ringPIP, .ringDIP, .ringTip])
        addFinger(&points, x: 0.62, extended: true, joints: [.littleMCP, .littlePIP, .littleDIP, .littleTip])
        return makeHand(points, offset: offset, confidence: confidence)
    }

    /// A bare hand at one spot: wrist, thumb tip and index tip all at `position`. Enough for the state machine.
    static func marker(at position: Vector2) -> Hand {
        let joint = Joint(x: position.x, y: position.y, confidence: 1)
        return Hand(isLeft: false, joints: [.wrist: joint, .thumbTip: joint, .indexTip: joint])
    }

    private static func addFinger(_ points: inout [JointName: Vector2], x: Double, extended: Bool, joints: [JointName]) {
        let ys = extended ? [0.6, 0.5, 0.43, 0.36] : [0.6, 0.52, 0.58, 0.64]
        for (joint, y) in zip(joints, ys) {
            points[joint] = Vector2(x: x, y: y)
        }
    }

    private static func makeHand(_ points: [JointName: Vector2], offset: Vector2, confidence: Double) -> Hand {
        var joints: [JointName: Joint] = [:]
        for (name, point) in points {
            joints[name] = Joint(x: point.x + offset.x, y: point.y + offset.y, confidence: confidence)
        }
        return Hand(isLeft: false, joints: joints)
    }
}
