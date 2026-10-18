/// A plain 2D point or velocity. Used by the gesture code so it needs no Apple frameworks.
struct Vector2: Sendable, Equatable, Codable {
    var x: Double
    var y: Double

    static let zero = Vector2(x: 0, y: 0)

    func distance(to other: Vector2) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }

    static func midpoint(_ a: Vector2, _ b: Vector2) -> Vector2 {
        Vector2(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

extension Joint {
    var position: Vector2 { Vector2(x: x, y: y) }
}
