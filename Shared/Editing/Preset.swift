/// One-tap looks (ED-3). A preset sets the base look; tool values still apply on top.
enum Preset: String, CaseIterable, Sendable, Codable {
    case original, vivid, warmFilm, coolMatte, noir, chrome

    var displayName: String {
        switch self {
        case .original: "Original"
        case .vivid: "Vivid"
        case .warmFilm: "Warm Film"
        case .coolMatte: "Cool Matte"
        case .noir: "Noir"
        case .chrome: "Chrome"
        }
    }
}
