/// Content-configured launch speed, flight duration, and collision radius for one launcher.
struct MissileLauncherComponent: Component {
    let speed: Double
    let lifetime: Double
    let radius: Double

    init(speed: Double, lifetime: Double, radius: Double) {
        precondition(speed.isFinite && speed > 0, "Missile speed must be finite and positive.")
        precondition(lifetime.isFinite && lifetime > 0, "Missile lifetime must be finite and positive.")
        let renderRadius = Float(radius)
        precondition(
            renderRadius.isFinite && renderRadius > 0,
            "Missile radius must remain finite and positive for rendering."
        )
        self.speed = speed
        self.lifetime = lifetime
        self.radius = radius
    }
}
