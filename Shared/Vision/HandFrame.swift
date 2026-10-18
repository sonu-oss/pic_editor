import Foundation

/// The 21 points Vision finds on a hand (wrist plus 4 per finger).
enum JointName: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case wrist
    case thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip
}

/// One point on a hand. x and y run from 0 to 1 with the origin at the top-left,
/// already mirrored so it lines up with the mirrored camera preview.
struct Joint: Sendable, Codable, Equatable {
    var x: Double
    var y: Double
    var confidence: Double

    init(x: Double, y: Double, confidence: Double) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }

    /// Converts a raw Vision point (origin bottom-left, not mirrored). HT-3: this is the only place it happens.
    init(visionX: Double, visionY: Double, confidence: Double) {
        self.init(x: 1 - visionX, y: 1 - visionY, confidence: confidence)
    }
}

struct Hand: Sendable, Codable, Equatable {
    var isLeft: Bool
    var joints: [JointName: Joint]
}

/// Everything the hand tracker saw in one camera frame (HT-2).
struct HandFrame: Sendable, Codable, Equatable {
    var timestamp: TimeInterval
    var hands: [Hand]
}
