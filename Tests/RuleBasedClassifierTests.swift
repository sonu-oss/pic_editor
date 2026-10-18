import Testing
@testable import GestureEdit

struct RuleBasedClassifierTests {
    let classifier = RuleBasedClassifier(config: HandFixtures.config)

    @Test(arguments: [HandPose.openPalm, .point, .peace, .thumbsUp, .fist, .pinch])
    func recognizesEachPose(_ pose: HandPose) {
        let hand = HandFixtures.hand(for: pose)
        #expect(classifier.classify(hand, previous: .none) == pose)
    }

    @Test func posesWorkAnywhereInTheFrame() {
        let hand = HandFixtures.hand(for: .peace, offset: Vector2(x: -0.3, y: -0.2))
        #expect(classifier.classify(hand, previous: .none) == .peace)
    }

    @Test func unclearHandIsNoPose() {
        let hand = HandFixtures.hand(for: .none)
        #expect(classifier.classify(hand, previous: .none) == .none)
    }

    @Test func lowConfidenceHandIsIgnored() {
        let hand = HandFixtures.hand(for: .openPalm, confidence: 0.1)
        #expect(classifier.classify(hand, previous: .none) == .none)
    }

    @Test func fistIsNotMistakenForPinch() {
        // In a fist the thumb rests on the curled index finger, close to its tip.
        let hand = HandFixtures.hand(for: .fist)
        #expect(classifier.classify(hand, previous: .pinch) == .fist)
    }

    @Test func pinchHasHysteresis() {
        // A gap between the enter (0.25) and exit (0.40) thresholds.
        let hand = HandFixtures.pinch(gap: 0.06)
        #expect(classifier.classify(hand, previous: .pinch) == .pinch)
        #expect(classifier.classify(hand, previous: .none) != .pinch)
    }

    @Test func pinchEndsWhenFingersSeparate() {
        let hand = HandFixtures.pinch(gap: 0.12)
        #expect(classifier.classify(hand, previous: .pinch) != .pinch)
    }
}

struct PoseStabilizerTests {
    @Test func newPoseNeedsFourOfFiveFrames() {
        var stabilizer = PoseStabilizer()
        var results: [HandPose] = []
        for _ in 0..<4 {
            results.append(stabilizer.add(.fist))
        }
        #expect(results == [.none, .none, .none, .fist])
    }

    @Test func singleGlitchFrameIsIgnored() {
        var stabilizer = PoseStabilizer()
        for _ in 0..<5 {
            _ = stabilizer.add(.openPalm)
        }
        let afterGlitch = stabilizer.add(.pinch)
        let afterRecovery = stabilizer.add(.openPalm)
        #expect(afterGlitch == .openPalm)
        #expect(afterRecovery == .openPalm)
    }
}

struct MotionTrackerTests {
    @Test func measuresVelocity() {
        var tracker = MotionTracker()
        let first = tracker.update(Vector2(x: 0.2, y: 0.5), at: 0)
        let second = tracker.update(Vector2(x: 0.3, y: 0.4), at: 0.1)
        #expect(first == .zero)
        #expect(abs(second.x - 1) < 1e-9)
        #expect(abs(second.y + 1) < 1e-9)
    }
}
