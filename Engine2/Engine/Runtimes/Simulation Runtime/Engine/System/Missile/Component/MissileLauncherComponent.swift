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

extension MissileLauncherComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        let isMissileLaunching = entity is MissileLaunching
        precondition(
            (state.missileSpeed != nil) == isMissileLaunching &&
                (state.missileLifetime != nil) == isMissileLaunching &&
                (state.missileRadius != nil) == isMissileLaunching,
            "MissileLaunching requires missile speed, lifetime, and radius; other entities must omit all three."
        )
        guard let missileSpeed = state.missileSpeed,
              let missileLifetime = state.missileLifetime,
              let missileRadius = state.missileRadius else {
            return nil
        }
        self.init(
            speed: missileSpeed,
            lifetime: missileLifetime,
            radius: missileRadius
        )
    }
}
