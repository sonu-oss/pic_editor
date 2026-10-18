/// Stops the pose from flickering (GE-2): a new pose only counts once it wins
/// `votes` of the last `window` frames. Until then the previous pose stays.
struct PoseStabilizer: Sendable {
    var window: Int
    var votes: Int
    private var recent: [HandPose] = []
    private(set) var stablePose: HandPose = .none

    init(window: Int = 5, votes: Int = 4) {
        self.window = window
        self.votes = votes
    }

    mutating func add(_ pose: HandPose) -> HandPose {
        recent.append(pose)
        if recent.count > window {
            recent.removeFirst(recent.count - window)
        }
        if recent.filter({ $0 == pose }).count >= votes {
            stablePose = pose
        }
        return stablePose
    }

    mutating func reset() {
        recent = []
        stablePose = .none
    }
}
