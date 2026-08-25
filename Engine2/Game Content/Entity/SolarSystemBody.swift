import simd

/// Renderable Solar System body backed by physical ECS state.
///
/// Position, velocity, mass, and physical radius use SI units. The uniform
/// `CScale` row is a symbolic model radius chosen only for whole-system
/// visibility; gravity and contact calculations continue to use
/// `CMassiveBody.physicalRadius`.
final class SolarSystemBody: Entity, PMovable, PRenderable, PScalable {
    /// Complete physical and presentation seed for one reference body.
    struct InitialState {
        let mass: AstronomicalMass
        let physicalRadius: AstronomicalDistance
        let position: SIMD3<Double>
        let velocity: SIMD3<Double>
        let symbolicModelRadiusMeters: Float
        let materialID: MaterialID
    }

    /// Registers one body only after all physical and presentation values pass admission.
    init(in world: World, from state: InitialState) {
        precondition(
            state.position.isFinite,
            "A Solar System body must have a finite position."
        )
        precondition(
            state.velocity.isFinite,
            "A Solar System body must have a finite velocity."
        )
        precondition(
            state.symbolicModelRadiusMeters.isFinite &&
                state.symbolicModelRadiusMeters > 0,
            "A Solar System body must have a positive finite symbolic model radius."
        )
        let massiveBody = CMassiveBody(
            mass: state.mass,
            physicalRadius: state.physicalRadius
        )

        super.init(unregisteredID: world.reserveEntityID(), in: world)

        world.add(
            self,
            from: Entity.InitialState(
                position: state.position,
                velocity: state.velocity,
                accelerationIntent: .idle,
                impulse: .zero,
                scale: SIMD3<Float>(
                    repeating: state.symbolicModelRadiusMeters
                )
            ),
            renderable: RenderableInitialState(
                meshID: .ball,
                materialID: state.materialID
            )
        )
        world.massiveBodyComponents.insert(massiveBody, for: id)
    }
}
