import Foundation
import Testing
@testable import GestureEdit

/// Record/replay (PRD Section 10): a session of hand frames, saved to JSON and replayed,
/// must produce the expected commands.
struct GesturePipelineTests {
    private func frames(_ pose: HandPose, for duration: Double, from start: Vector2, to end: Vector2, time: inout Double) -> [HandFrame] {
        let steps = Int((duration * 30).rounded())
        return (1...steps).map { step in
            time += 1.0 / 30
            let fraction = Double(step) / Double(steps)
            let offset = Vector2(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
            return HandFrame(timestamp: time, hands: [HandFixtures.hand(for: pose, offset: offset)])
        }
    }

    private func recordedSession() -> HandSession {
        var time = 0.0
        let here = Vector2.zero
        let raised = Vector2(x: 0, y: -0.15)
        var all: [HandFrame] = []
        all += frames(.openPalm, for: 1.0, from: here, to: here, time: &time)
        all += frames(.pinch, for: 0.5, from: here, to: raised, time: &time)
        all += frames(.openPalm, for: 0.3, from: raised, to: raised, time: &time)
        all += frames(.peace, for: 0.4, from: raised, to: raised, time: &time)
        all += frames(.fist, for: 0.3, from: raised, to: raised, time: &time)
        return HandSession(frames: all)
    }

    @Test func replayedSessionProducesExpectedCommands() throws {
        // Round-trip through JSON, like a file saved by the "Record gestures" button.
        let data = try JSONEncoder().encode(recordedSession())
        let session = try JSONDecoder().decode(HandSession.self, from: data)

        var pipeline = GesturePipeline(config: HandFixtures.config)
        var commands: [EditCommand] = []
        for frame in session.frames {
            commands += pipeline.process(frame)
        }

        let actions = commands.filter {
            if case .adjust = $0 { return false }
            if case .cursor = $0 { return false }
            return true
        }
        #expect(actions == [.arm, .beginAdjust, .endAdjust, .undo, .disarm])

        let raised = commands.compactMap { command -> Double? in
            if case .adjust(let delta) = command { return delta }
            return nil
        }.reduce(0, +)
        #expect(raised > 0.03)
        #expect(pipeline.stateMachine.state == .idle)
    }

    @Test func picksTheBiggestHand() {
        var pipeline = GesturePipeline(config: HandFixtures.config)
        var small = HandFixtures.hand(for: .fist)
        // Shrink the fist toward its wrist so it looks farther away.
        for (name, joint) in small.joints {
            small.joints[name] = Joint(x: 0.5 + (joint.x - 0.5) * 0.5, y: 0.8 + (joint.y - 0.8) * 0.5, confidence: 1)
        }
        let big = HandFixtures.hand(for: .openPalm)
        _ = pipeline.process(HandFrame(timestamp: 0, hands: [small, big]))
        #expect(pipeline.rawPose == .openPalm)
    }
}
