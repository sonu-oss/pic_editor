import Foundation

/// Smooths a jittery signal (HT-4). When the hand is still it smooths a lot;
/// when the hand moves fast it smooths less, so it doesn't lag behind.
/// Paper: https://gery.casiez.net/1euro/
struct OneEuroFilter: Sendable {
    var minCutoff: Double
    var beta: Double
    var derivativeCutoff: Double

    private var previousValue: Double?
    private var previousDerivative = 0.0
    private var previousTime: TimeInterval?

    init(minCutoff: Double = 1.0, beta: Double = 0.007, derivativeCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    /// Feeds one new sample and returns the smoothed value.
    mutating func filter(_ value: Double, at time: TimeInterval) -> Double {
        guard let lastValue = previousValue, let lastTime = previousTime else {
            previousValue = value
            previousTime = time
            return value
        }
        let dt = time - lastTime
        guard dt > 0 else { return lastValue }

        let derivative = (value - lastValue) / dt
        let smoothedDerivative = Self.blend(previousDerivative, derivative, Self.alpha(cutoff: derivativeCutoff, dt: dt))
        let cutoff = minCutoff + beta * abs(smoothedDerivative)
        let result = Self.blend(lastValue, value, Self.alpha(cutoff: cutoff, dt: dt))

        previousValue = result
        previousDerivative = smoothedDerivative
        previousTime = time
        return result
    }

    mutating func reset() {
        previousValue = nil
        previousDerivative = 0
        previousTime = nil
    }

    private static func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1 / (2 * Double.pi * cutoff)
        return 1 / (1 + tau / dt)
    }

    private static func blend(_ old: Double, _ new: Double, _ alpha: Double) -> Double {
        old + alpha * (new - old)
    }
}
