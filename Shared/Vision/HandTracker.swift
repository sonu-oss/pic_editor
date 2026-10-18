import CoreVideo
import Foundation
import Vision

/// Finds up to 2 hands in a camera frame with Vision (HT-1) and turns them into a HandFrame.
///
/// It runs directly on the camera's video queue, one frame at a time. While it is busy,
/// the camera throws away new frames (alwaysDiscardsLateVideoFrames), which is how
/// HT-5 "drop the frame if Vision is still busy" is handled.
/// Marked @unchecked Sendable because it is only ever used from that one queue.
final class HandTracker: @unchecked Sendable {
    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()

    func process(_ pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> HandFrame {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return HandFrame(timestamp: timestamp, hands: [])
        }
        let observations = request.results ?? []
        let hands = observations.compactMap { Self.makeHand(from: $0) }
        return HandFrame(timestamp: timestamp, hands: hands)
    }

    private static func makeHand(from observation: VNHumanHandPoseObservation) -> Hand? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }
        var joints: [JointName: Joint] = [:]
        for name in JointName.allCases {
            guard let point = points[name.visionName] else { continue }
            joints[name] = Joint(
                visionX: Double(point.location.x),
                visionY: Double(point.location.y),
                confidence: Double(point.confidence)
            )
        }
        return Hand(isLeft: observation.chirality == .left, joints: joints)
    }
}

private extension JointName {
    var visionName: VNHumanHandPoseObservation.JointName {
        switch self {
        case .wrist: .wrist
        case .thumbCMC: .thumbCMC
        case .thumbMP: .thumbMP
        case .thumbIP: .thumbIP
        case .thumbTip: .thumbTip
        case .indexMCP: .indexMCP
        case .indexPIP: .indexPIP
        case .indexDIP: .indexDIP
        case .indexTip: .indexTip
        case .middleMCP: .middleMCP
        case .middlePIP: .middlePIP
        case .middleDIP: .middleDIP
        case .middleTip: .middleTip
        case .ringMCP: .ringMCP
        case .ringPIP: .ringPIP
        case .ringDIP: .ringDIP
        case .ringTip: .ringTip
        case .littleMCP: .littleMCP
        case .littlePIP: .littlePIP
        case .littleDIP: .littleDIP
        case .littleTip: .littleTip
        }
    }
}
