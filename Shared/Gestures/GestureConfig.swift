/// Every gesture threshold in one place (GE-5). Tune these first when a gesture feels off.
/// Distances are relative to hand size, so they work near and far from the camera.
struct GestureConfig: Sendable, Equatable {
    /// Camera frame width ÷ height. Joint x and y are both 0…1, so x is stretched by this
    /// before measuring distances, to keep circles round.
    var aspectRatio = 16.0 / 9.0

    // MARK: Pose detection (RuleBasedClassifier)

    /// Joints Vision is less sure about than this are ignored.
    var minimumJointConfidence = 0.3
    /// A hand with fewer confident joints than this counts as no pose.
    var minimumConfidentJoints = 15
    /// A finger is extended when wrist→tip is longer than this × wrist→middle knuckle (PIP).
    /// The PRD's 1.3 was too strict on real hands: a straight finger only reaches about 1.3–1.35,
    /// so an open palm often read as "no pose". A curled finger is below about 0.8.
    var fingerExtendedRatio = 1.1
    /// The thumb is extended when thumb tip→index base is longer than this × hand size.
    var thumbExtendedRatio = 0.6
    /// Pinch starts when thumb tip→index tip is below this × hand size…
    var pinchEnterRatio = 0.25
    /// …and ends only when it goes above this (the gap stops flicker).
    var pinchExitRatio = 0.40
    /// The index finger must reach at least this × its middle knuckle distance, so a fist
    /// (thumb resting on a curled index) isn't read as a pinch.
    var pinchMinimumIndexReach = 1.0

    // MARK: Pose voting (PoseStabilizer)

    /// A pose counts once it wins `stableVotes` of the last `stableWindow` frames.
    var stableWindow = 5
    var stableVotes = 4

    // MARK: Gesture states (GestureStateMachine), times in seconds

    var armHoldDuration = 0.8
    /// Wrist speed for a swipe, in camera widths per second. (PRD said 1.5; too fast in practice.)
    var swipeVelocity = 0.8
    var swipeMinimumFrames = 2
    /// A fast hand often blurs and stops looking like a palm. It still counts as a palm swipe
    /// if the palm was seen this recently.
    var swipePalmGrace = 0.4
    var swipeCooldown = 0.5
    /// A pinch must be held this long before moving the hand changes the value.
    var pinchSettleDuration = 0.15
    var dwellDuration = 0.8
    /// How far the pointing finger may wander (camera heights) and still count as holding still.
    var dwellRadius = 0.03
    var exportHoldDuration = 1.0
    var autoDisarmDelay = 5.0
}
