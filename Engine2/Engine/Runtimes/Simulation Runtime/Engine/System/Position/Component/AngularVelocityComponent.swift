/// Axis-rate angular velocity in radians per second.
struct AngularVelocityComponent: Component {
    let angularVelocity: SIMD3<Float>
}

extension AngularVelocityComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(state.angularVelocity == nil || entity is Rotatable,
                     "Initial state.angularVelocity requires Rotatable conformance")
        guard entity is Rotatable else { return nil }
        self.init(angularVelocity: state.angularVelocity ?? .zero)
    }
}
