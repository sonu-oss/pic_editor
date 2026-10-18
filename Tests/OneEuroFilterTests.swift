import Foundation
import Testing
@testable import GestureEdit

struct OneEuroFilterTests {
    @Test func firstValuePassesThrough() {
        var filter = OneEuroFilter()
        let output = filter.filter(5, at: 0)
        #expect(output == 5)
    }

    @Test func steadyValueStaysSteady() {
        var filter = OneEuroFilter()
        var output = 0.0
        for frame in 0..<60 {
            output = filter.filter(2, at: Double(frame) / 30)
        }
        #expect(abs(output - 2) < 1e-9)
    }

    @Test func suddenJumpIsSmoothed() {
        var filter = OneEuroFilter()
        _ = filter.filter(0, at: 0)
        let output = filter.filter(1, at: 1.0 / 30)
        #expect(output > 0)
        #expect(output < 0.5)
    }

    @Test func catchesUpWithANewValue() {
        var filter = OneEuroFilter()
        _ = filter.filter(0, at: 0)
        var output = 0.0
        for frame in 1...90 {
            output = filter.filter(1, at: Double(frame) / 30)
        }
        #expect(output > 0.99)
    }

    @Test func repeatedTimestampKeepsLastValue() {
        var filter = OneEuroFilter()
        _ = filter.filter(0, at: 1)
        let output = filter.filter(5, at: 1)
        #expect(output == 0)
    }

    @Test func resetStartsFresh() {
        var filter = OneEuroFilter()
        _ = filter.filter(0, at: 0)
        filter.reset()
        let output = filter.filter(7, at: 1.0 / 30)
        #expect(output == 7)
    }
}
