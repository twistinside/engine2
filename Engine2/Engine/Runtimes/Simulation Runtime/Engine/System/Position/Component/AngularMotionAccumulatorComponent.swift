/// Per-frame angular motion contributions.
///
/// `angularAcceleration` is a continuous rotational influence scaled by
/// `deltaTime`; `angularImpulse` is an immediate angular velocity delta.
struct AngularMotionAccumulatorComponent: Component {
    let angularAcceleration: SIMD3<Float>
    let angularImpulse: SIMD3<Float>
}

extension AngularMotionAccumulatorComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.angularAcceleration == nil && state.angularImpulse == nil) || entity is Rotatable,
            "Initial angular accumulator state requires Rotatable conformance"
        )
        guard entity is Rotatable else { return nil }
        self.init(
            angularAcceleration: state.angularAcceleration ?? .zero,
            angularImpulse: state.angularImpulse ?? .zero
        )
    }
}
