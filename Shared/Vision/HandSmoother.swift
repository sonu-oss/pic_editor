import Foundation

/// Runs a One Euro filter on the x and y of every joint of every hand.
/// Filters are kept per hand side (left/right) and reset when a hand leaves the frame.
struct HandSmoother: Sendable {
    var minCutoff = 1.0
    var beta = 0.007
    var derivativeCutoff = 1.0

    private struct Key: Hashable, Sendable {
        let isLeft: Bool
        let joint: JointName
    }

    private struct AxisFilters: Sendable {
        var x: OneEuroFilter
        var y: OneEuroFilter
    }

    private var filters: [Key: AxisFilters] = [:]

    mutating func smooth(_ frame: HandFrame) -> HandFrame {
        var result = frame
        var seen = Set<Key>()
        for handIndex in frame.hands.indices {
            let hand = frame.hands[handIndex]
            for (name, joint) in hand.joints {
                let key = Key(isLeft: hand.isLeft, joint: name)
                seen.insert(key)
                var axis = filters[key] ?? AxisFilters(x: makeFilter(), y: makeFilter())
                var smoothed = joint
                smoothed.x = axis.x.filter(joint.x, at: frame.timestamp)
                smoothed.y = axis.y.filter(joint.y, at: frame.timestamp)
                filters[key] = axis
                result.hands[handIndex].joints[name] = smoothed
            }
        }
        filters = filters.filter { seen.contains($0.key) }
        return result
    }

    mutating func reset() {
        filters = [:]
    }

    private func makeFilter() -> OneEuroFilter {
        OneEuroFilter(minCutoff: minCutoff, beta: beta, derivativeCutoff: derivativeCutoff)
    }
}
