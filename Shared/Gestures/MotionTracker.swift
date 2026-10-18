/// Works out how fast a point is moving (GE-3), in camera widths/heights per second.
struct MotionTracker: Sendable {
    private var lastPoint: Vector2?
    private var lastTime: Double?

    mutating func update(_ point: Vector2, at time: Double) -> Vector2 {
        defer {
            lastPoint = point
            lastTime = time
        }
        guard let lastPoint, let lastTime, time > lastTime else { return .zero }
        let dt = time - lastTime
        return Vector2(x: (point.x - lastPoint.x) / dt, y: (point.y - lastPoint.y) / dt)
    }

    mutating func reset() {
        lastPoint = nil
        lastTime = nil
    }
}
