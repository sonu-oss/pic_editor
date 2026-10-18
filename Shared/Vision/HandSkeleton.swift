/// Which joints are connected by a line when we draw a hand.
enum HandSkeleton {
    struct Bone: Sendable {
        let from: JointName
        let to: JointName
    }

    static let bones: [Bone] = {
        let fingers: [[JointName]] = [
            [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
            [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
            [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
            [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
            [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip],
        ]
        var bones: [Bone] = []
        for finger in fingers {
            for index in 1..<finger.count {
                bones.append(Bone(from: finger[index - 1], to: finger[index]))
            }
        }
        // Across the knuckles, so the palm reads as a shape.
        bones.append(Bone(from: .indexMCP, to: .middleMCP))
        bones.append(Bone(from: .middleMCP, to: .ringMCP))
        bones.append(Bone(from: .ringMCP, to: .littleMCP))
        return bones
    }()
}
