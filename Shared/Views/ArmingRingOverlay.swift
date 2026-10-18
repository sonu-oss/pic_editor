import SwiftUI

/// UI-3: a ring around the palm in the camera view that fills while the open palm is held to arm.
struct ArmingRingOverlay: View {
    let hand: Hand?
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            if progress > 0, let hand, let wrist = hand.joints[.wrist], let middleBase = hand.joints[.middleMCP] {
                let size = geometry.size
                let a = CGPoint(x: wrist.x * size.width, y: wrist.y * size.height)
                let b = CGPoint(x: middleBase.x * size.width, y: middleBase.y * size.height)
                let center = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let handSize = hypot(a.x - b.x, a.y - b.y)
                let diameter = max(handSize * 2.4, 30)
                ProgressRing(progress: progress, lineWidth: 5)
                    .frame(width: diameter, height: diameter)
                    .position(center)
            }
        }
        .allowsHitTesting(false)
    }
}
