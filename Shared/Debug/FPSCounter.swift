import Foundation

/// Counts how many frames arrived in the last second.
struct FPSCounter: Sendable {
    var window: TimeInterval = 1
    private var timestamps: [TimeInterval] = []

    /// Records a frame and returns the current frames-per-second.
    mutating func record(_ timestamp: TimeInterval) -> Double {
        timestamps.append(timestamp)
        timestamps.removeAll { $0 <= timestamp - window }
        return Double(timestamps.count) / window
    }

    mutating func reset() {
        timestamps = []
    }
}
