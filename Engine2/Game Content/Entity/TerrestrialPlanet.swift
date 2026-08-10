import simd

/// Game Content entity for one layered terrestrial planet.
///
/// The entity registers one authoritative transform and one backend-neutral
/// mesh/material pair. Render expands that material into its private surface,
/// cloud, and atmosphere layers without adding Render-only entities to ECS.
final class TerrestrialPlanet: Entity, PPositionable, POrientable, PScalable, PRenderable, PSelectable {
    /// Authored Apollo-style pose centered south of Africa.
    static let standardRotation = simd_quatf(
        angle: -.pi * 5 / 36,
        axis: SIMD3<Float>(1, 0, 0)
    ) * simd_quatf(
        angle: -.pi * 13 / 36,
        axis: SIMD3<Float>(0, 1, 0)
    )

    /// Uniform scale that frames the unit-radius planet under the proof camera.
    static let standardScale = SIMD3<Float>(repeating: 2.5)

    /// Registers a terrestrial planet with a positive, uniform static scale.
    convenience init(
        in world: World,
        position: SIMD3<Float> = .zero,
        rotation: simd_quatf = standardRotation,
        scale: SIMD3<Float> = standardScale,
        selectionState: CSelectable.SelectionState = .unselected
    ) {
        precondition(
            scale.isFinite
                && scale.x > 0
                && scale.x == scale.y
                && scale.y == scale.z,
            "Terrestrial planets require a finite, positive uniform scale."
        )
        self.init(unregisteredID: world.reserveEntityID(), in: world)
        let initialState = Entity.InitialState(
            position: position,
            rotation: rotation,
            scale: scale,
            selectionState: selectionState
        )
        let renderableState = RenderableInitialState(
            meshID: .terrestrialPlanet,
            materialID: .terrestrialPlanet
        )
        world.add(self, from: initialState, renderable: renderableState)
    }
}
