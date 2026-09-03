/// Per-frame angular motion contributions.
///
/// `angularAcceleration` is a continuous rotational influence scaled by
/// `deltaTime`; `angularImpulse` is an immediate angular velocity delta.
struct AngularMotionAccumulatorComponent: Component {
    let angularAcceleration: SIMD3<Float>
    let angularImpulse: SIMD3<Float>
}
