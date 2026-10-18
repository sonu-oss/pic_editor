import Foundation
import Testing
@testable import GestureEdit

private func frame(_ time: TimeInterval, wristX: Double, isLeft: Bool = false) -> HandFrame {
    HandFrame(
        timestamp: time,
        hands: [Hand(isLeft: isLeft, joints: [.wrist: Joint(x: wristX, y: 0.5, confidence: 1)])]
    )
}

struct JointConversionTests {
    @Test func visionPointIsFlippedAndMirrored() {
        // Vision: origin bottom-left, not mirrored. Ours: origin top-left, mirrored.
        let joint = Joint(visionX: 0.2, visionY: 0.9, confidence: 0.8)
        #expect(abs(joint.x - 0.8) < 1e-9)
        #expect(abs(joint.y - 0.1) < 1e-9)
        #expect(joint.confidence == 0.8)
    }

    @Test func handFrameRoundTripsThroughJSON() throws {
        let original = frame(1.5, wristX: 0.25, isLeft: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HandFrame.self, from: data)
        #expect(decoded == original)
    }
}

struct HandSmootherTests {
    @Test func firstFramePassesThrough() {
        var smoother = HandSmoother()
        let input = frame(0, wristX: 0.3)
        let output = smoother.smooth(input)
        #expect(output == input)
    }

    @Test func jumpIsSmoothed() throws {
        var smoother = HandSmoother()
        _ = smoother.smooth(frame(0, wristX: 0))
        let output = smoother.smooth(frame(1.0 / 30, wristX: 1))
        let x = try #require(output.hands.first?.joints[.wrist]?.x)
        #expect(x > 0)
        #expect(x < 0.5)
    }

    @Test func handThatLeavesStartsFreshWhenItReturns() {
        var smoother = HandSmoother()
        _ = smoother.smooth(frame(0, wristX: 0))
        _ = smoother.smooth(HandFrame(timestamp: 1.0 / 30, hands: []))
        let returning = frame(2.0 / 30, wristX: 1)
        let output = smoother.smooth(returning)
        #expect(output == returning)
    }
}

struct FPSCounterTests {
    @Test func countsFramesInTheLastSecond() {
        var counter = FPSCounter()
        var fps = 0.0
        for frame in 0..<30 {
            fps = counter.record(Double(frame) / 30)
        }
        #expect(fps == 30)
    }

    @Test func forgetsOldFrames() {
        var counter = FPSCounter()
        for frame in 0..<30 {
            _ = counter.record(Double(frame) / 30)
        }
        let fps = counter.record(5)
        #expect(fps == 1)
    }
}

@MainActor
struct AppModelTests {
    @Test func receivingAFrameUpdatesHands() {
        let model = AppModel()
        let input = frame(0, wristX: 0.4)
        model.receive(input)
        #expect(model.hands == input.hands)
    }

    @Test func smoothingOffPassesFramesThroughUnchanged() {
        let model = AppModel()
        model.smoothingEnabled = false
        model.receive(frame(0, wristX: 0))
        let second = frame(1.0 / 30, wristX: 1)
        model.receive(second)
        #expect(model.hands == second.hands)
    }

    @Test func cameraOnlyRunsWhenAppIsActiveAndVisible() {
        let model = AppModel()
        #expect(model.cameraShouldRun)
        model.isAppActive = false
        #expect(!model.cameraShouldRun)
        model.isAppActive = true
        model.isWindowMinimized = true
        #expect(!model.cameraShouldRun)
    }

    @Test func swipeCommandsChangeTheTool() {
        let model = AppModel()
        model.apply(.nextTool)
        #expect(model.activeTool == .brightness)
        model.apply(.previousTool)
        model.apply(.previousTool)
        #expect(model.activeTool == .sharpness)
    }

    @Test func cancelRestoresTheValue() {
        let model = AppModel()
        model.apply(.beginAdjust)
        model.apply(.adjust(delta: 0.25))
        #expect(model.value(of: .exposure) == 1)
        model.apply(.cancelAdjust)
        #expect(model.value(of: .exposure) == 0)
    }

    @Test func valuesStayInRange() {
        let model = AppModel()
        model.apply(.beginAdjust)
        model.apply(.adjust(delta: 5))
        model.apply(.endAdjust)
        #expect(model.value(of: .exposure) == 2)
    }
}
