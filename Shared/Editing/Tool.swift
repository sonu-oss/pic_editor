import Foundation

/// The adjustment tools, in swipe order (PRD Section 4).
enum Tool: String, CaseIterable, Sendable, Codable, CodingKeyRepresentable {
    case exposure, brightness, contrast, saturation, warmth, highlights, shadows, vignette, sharpness

    var displayName: String {
        switch self {
        case .exposure: "Exposure"
        case .brightness: "Brightness"
        case .contrast: "Contrast"
        case .saturation: "Saturation"
        case .warmth: "Warmth"
        case .highlights: "Highlights"
        case .shadows: "Shadows"
        case .vignette: "Vignette"
        case .sharpness: "Sharpness"
        }
    }

    /// Lowest and highest allowed value. A pinch moved the full camera height covers the whole range.
    var range: ClosedRange<Double> {
        switch self {
        case .exposure: -2...2
        case .brightness: -0.5...0.5
        case .contrast: 0.5...1.5
        case .saturation: 0...2
        case .warmth: 4000...9000
        case .highlights: 0...1
        case .shadows: -1...1
        case .vignette: 0...2
        case .sharpness: 0...2
        }
    }

    /// The "no change" value (matches EditState in the PRD).
    var defaultValue: Double {
        switch self {
        case .exposure, .brightness, .shadows, .vignette, .sharpness: 0
        case .contrast, .saturation, .highlights: 1
        case .warmth: 6500
        }
    }

    var span: Double { range.upperBound - range.lowerBound }

    func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    func formatted(_ value: Double) -> String {
        switch self {
        case .warmth: "\(Int(value.rounded())) K"
        case .exposure: (value >= 0 ? "+" : "") + String(format: "%.2f EV", value)
        default: String(format: "%.2f", value)
        }
    }

    var next: Tool { offset(by: 1) }
    var previous: Tool { offset(by: -1) }

    private func offset(by step: Int) -> Tool {
        let all = Tool.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + step + all.count) % all.count]
    }
}
