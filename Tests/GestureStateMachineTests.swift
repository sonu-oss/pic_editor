import Testing
@testable import GestureEdit

/// Feeds the state machine a pose for a stretch of time at 30 fps, optionally moving the hand.
private struct Driver {
    var machine = GestureStateMachine(config: HandFixtures.config)
    var time = 0.0
    var position = Vector2(x: 0.5, y: 0.5)
    let frameDuration = 1.0 / 30

    @discardableResult
    mutating func run(_ pose: HandPose, for duration: Double, to end: Vector2? = nil, handVisible: Bool = true) -> [EditCommand] {
        let start = position
        let target = end ?? position
        let steps = max(Int((duration / frameDuration).rounded()), 1)
        var commands: [EditCommand] = []
        for step in 1...steps {
            time += frameDuration
            let fraction = Double(step) / Double(steps)
            position = Vector2(x: start.x + (target.x - start.x) * fraction, y: start.y + (target.y - start.y) * fraction)
            let hand = handVisible ? HandFixtures.marker(at: position) : nil
            commands += machine.consume(GestureInput(timestamp: time, pose: pose, hand: hand))
        }
        return commands
    }

    mutating func arm() {
        run(.openPalm, for: 0.9)
    }
}

private func adjustments(_ commands: [EditCommand]) -> [Double] {
    commands.compactMap { command -> Double? in
        if case .adjust(let delta) = command { return delta }
        return nil
    }
}

struct GestureStateMachineTests {
    // MARK: Arming

    @Test func armsAfterHoldingAnOpenPalm() {
        var driver = Driver()
        let result1 = driver.run(.openPalm, for: 0.5)
        #expect(result1.isEmpty)
        #expect(driver.machine.state == .idle)
        #expect(driver.machine.armProgress > 0.5)
        let result2 = driver.run(.openPalm, for: 0.4)
        #expect(result2 == [.arm])
        #expect(driver.machine.state == .armed)
    }

    @Test func briefPalmsDoNotArm() {
        var driver = Driver()
        driver.run(.openPalm, for: 0.5)
        driver.run(.none, for: 0.1)
        let result3 = driver.run(.openPalm, for: 0.5)
        #expect(result3.isEmpty)
        #expect(driver.machine.state == .idle)
    }

    @Test func idleIgnoresEditingGestures() {
        var driver = Driver()
        var commands = driver.run(.pinch, for: 1)
        commands += driver.run(.peace, for: 1)
        commands += driver.run(.thumbsUp, for: 2)
        commands += driver.run(.fist, for: 1)
        commands += driver.run(.point, for: 1)
        #expect(commands.isEmpty)
        #expect(driver.machine.state == .idle)
    }

    // MARK: Disarming

    @Test func fistDisarms() {
        var driver = Driver()
        driver.arm()
        let result4 = driver.run(.fist, for: 0.1)
        #expect(result4 == [.disarm])
        #expect(driver.machine.state == .idle)
    }

    @Test func autoDisarmsAfterFiveSecondsWithoutAHand() {
        var driver = Driver()
        driver.arm()
        let result5 = driver.run(.none, for: 4.8, handVisible: false)
        #expect(result5.isEmpty)
        let result6 = driver.run(.none, for: 0.3, handVisible: false)
        #expect(result6 == [.disarm])
        #expect(driver.machine.state == .idle)
    }

    // MARK: Pinch adjusting

    @Test func pinchWaitsToSettleThenAdjustsUpward() {
        var driver = Driver()
        driver.arm()
        let result7 = driver.run(.pinch, for: 0.1)
        #expect(result7 == [.beginAdjust])
        #expect(driver.machine.state == .adjusting)

        let deltas = adjustments(driver.run(.pinch, for: 0.5, to: Vector2(x: 0.5, y: 0.3)))
        #expect(!deltas.isEmpty)
        #expect(deltas.allSatisfy { $0 > 0 })
        #expect(deltas.reduce(0, +) > 0.1)
    }

    @Test func movingDownLowersTheValue() {
        var driver = Driver()
        driver.arm()
        driver.run(.pinch, for: 0.2)
        let deltas = adjustments(driver.run(.pinch, for: 0.5, to: Vector2(x: 0.5, y: 0.8)))
        #expect(deltas.reduce(0, +) < -0.1)
    }

    @Test func releasingThePinchEndsTheAdjustment() {
        var driver = Driver()
        driver.arm()
        driver.run(.pinch, for: 0.3)
        let result8 = driver.run(.openPalm, for: 0.1)
        #expect(result8 == [.endAdjust])
        #expect(driver.machine.state == .armed)
    }

    @Test func fistCancelsWithoutDisarming() {
        var driver = Driver()
        driver.arm()
        driver.run(.pinch, for: 0.3)
        let result9 = driver.run(.fist, for: 0.3)
        #expect(result9 == [.cancelAdjust])
        #expect(driver.machine.state == .armed)
        // A fresh fist afterwards does disarm.
        driver.run(.none, for: 0.1)
        let result10 = driver.run(.fist, for: 0.1)
        #expect(result10 == [.disarm])
    }

    @Test func losingTheHandFreezesTheValue() {
        var driver = Driver()
        driver.arm()
        driver.run(.pinch, for: 0.3)
        let commands = driver.run(.none, for: 0.1, handVisible: false)
        #expect(commands == [.endAdjust])
        #expect(driver.machine.state == .armed)
    }

    // MARK: Swipes

    @Test func swipeRightSelectsNextToolOnce() {
        var driver = Driver()
        driver.arm()
        driver.run(.openPalm, for: 0.6)
        let result11 = driver.run(.openPalm, for: 0.2, to: Vector2(x: 0.9, y: 0.5))
        #expect(result11 == [.nextTool])
    }

    @Test func swipeLeftSelectsPreviousTool() {
        var driver = Driver()
        driver.arm()
        driver.run(.openPalm, for: 0.6)
        let result12 = driver.run(.openPalm, for: 0.2, to: Vector2(x: 0.1, y: 0.5))
        #expect(result12 == [.previousTool])
    }

    @Test func swipesHaveACooldown() {
        var driver = Driver()
        driver.arm()
        driver.run(.openPalm, for: 0.6)
        let result13 = driver.run(.openPalm, for: 0.2, to: Vector2(x: 0.9, y: 0.5))
        #expect(result13 == [.nextTool])
        let result14 = driver.run(.openPalm, for: 0.2, to: Vector2(x: 1.3, y: 0.5))
        #expect(result14.isEmpty)
        driver.run(.openPalm, for: 0.6)
        let result15 = driver.run(.openPalm, for: 0.2, to: Vector2(x: 0.9, y: 0.5))
        #expect(result15 == [.previousTool])
    }

    @Test func slowMovementIsNotASwipe() {
        var driver = Driver()
        driver.arm()
        driver.run(.openPalm, for: 0.6)
        let result16 = driver.run(.openPalm, for: 1, to: Vector2(x: 0.9, y: 0.5))
        #expect(result16.isEmpty)
    }

    @Test func noSwipeRightAfterArming() {
        var driver = Driver()
        driver.arm()
        let result17 = driver.run(.openPalm, for: 0.2, to: Vector2(x: 0.9, y: 0.5))
        #expect(result17.isEmpty)
    }

    // MARK: Undo and export

    @Test func peaceUndoesOncePerGesture() {
        var driver = Driver()
        driver.arm()
        let result18 = driver.run(.peace, for: 1)
        #expect(result18 == [.undo])
        driver.run(.none, for: 0.1)
        let result19 = driver.run(.peace, for: 0.1)
        #expect(result19 == [.undo])
    }

    @Test func thumbsUpExportsAfterOneSecond() {
        var driver = Driver()
        driver.arm()
        let result20 = driver.run(.thumbsUp, for: 0.9)
        #expect(result20.isEmpty)
        #expect(driver.machine.exportProgress > 0.8)
        let result21 = driver.run(.thumbsUp, for: 0.2)
        #expect(result21 == [.export])
        let result22 = driver.run(.thumbsUp, for: 2)
        #expect(result22.isEmpty)
    }

    // MARK: Pointing

    @Test func pointingMovesTheCursorAndDwellClicks() {
        var driver = Driver()
        driver.arm()
        let first = driver.run(.point, for: 0.5)
        #expect(driver.machine.state == .pointing)
        #expect(first.contains(.cursor(x: 0.5, y: 0.5)))
        #expect(!first.contains(.click))
        let result23 = driver.run(.point, for: 0.4)
        #expect(result23.filter { $0 == .click }.count == 1)
        let result24 = driver.run(.point, for: 1)
        #expect(!result24.contains(.click))
    }

    @Test func movingFingerDoesNotClick() {
        var driver = Driver()
        driver.arm()
        let result25 = driver.run(.point, for: 1, to: Vector2(x: 0.9, y: 0.5))
        #expect(!result25.contains(.click))
    }

    @Test func leavingThePointReturnsToArmed() {
        var driver = Driver()
        driver.arm()
        driver.run(.point, for: 0.2)
        driver.run(.none, for: 0.1)
        #expect(driver.machine.state == .armed)
    }

    @Test func blurredFastPalmStillSwipes() {
        var driver = Driver()
        driver.arm()
        driver.run(.openPalm, for: 0.6)
        // Mid-swipe the hand blurs and the pose drops to "none".
        let swipe = driver.run(.none, for: 0.2, to: Vector2(x: 0.9, y: 0.5))
        #expect(swipe == [.nextTool])
    }

    @Test func movingWithoutAPalmIsNotASwipe() {
        var driver = Driver()
        driver.arm()
        driver.run(.none, for: 0.6)
        let moved = driver.run(.none, for: 0.2, to: Vector2(x: 0.9, y: 0.5))
        #expect(moved.isEmpty)
    }
}
