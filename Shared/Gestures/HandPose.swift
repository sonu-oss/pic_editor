/// The poses the app understands (GE-1).
enum HandPose: String, Sendable, Codable, CaseIterable {
    case openPalm, pinch, point, peace, thumbsUp, fist, none

    var displayName: String {
        switch self {
        case .openPalm: "Open palm"
        case .pinch: "Pinch"
        case .point: "Point"
        case .peace: "Peace"
        case .thumbsUp: "Thumbs up"
        case .fist: "Fist"
        case .none: "No pose"
        }
    }

    var emoji: String {
        switch self {
        case .openPalm: "✋"
        case .pinch: "🤏"
        case .point: "☝️"
        case .peace: "✌️"
        case .thumbsUp: "👍"
        case .fist: "✊"
        case .none: "·"
        }
    }
}

/// Anything that can look at a hand and name its pose (GE-1).
/// `previous` is the last pose this classifier returned, for rules that need memory (pinch hysteresis).
protocol GestureClassifier: Sendable {
    func classify(_ hand: Hand, previous: HandPose) -> HandPose
}
