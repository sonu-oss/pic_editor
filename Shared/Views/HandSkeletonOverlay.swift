import SwiftUI

/// Draws the tracked hands as dots and lines (UI-5). Joints Vision isn't sure about are skipped.
struct HandSkeletonOverlay: View {
    let hands: [Hand]
    var minimumConfidence = 0.3

    var body: some View {
        Canvas { context, size in
            for hand in hands {
                let point: (JointName) -> CGPoint? = { name in
                    guard let joint = hand.joints[name], joint.confidence >= minimumConfidence else { return nil }
                    return CGPoint(x: joint.x * size.width, y: joint.y * size.height)
                }

                var bones = Path()
                for bone in HandSkeleton.bones {
                    if let start = point(bone.from), let end = point(bone.to) {
                        bones.move(to: start)
                        bones.addLine(to: end)
                    }
                }
                context.stroke(bones, with: .color(hand.isLeft ? .cyan : .yellow), lineWidth: 2)

                for name in JointName.allCases {
                    if let center = point(name) {
                        let dot = CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)
                        context.fill(Path(ellipseIn: dot), with: .color(.white))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
