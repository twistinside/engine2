//
//  CAngularMotionAccumulator.swift
//  Engine2
//
//  Created by Codex on 3/15/26.
//

/// Per-frame angular motion contributions.
///
/// `angularAcceleration` is a continuous rotational influence scaled by
/// `deltaTime`; `angularImpulse` is an immediate angular velocity delta.
struct CAngularMotionAccumulator: Component {
    let angularAcceleration: SIMD3<Float>
    let angularImpulse: SIMD3<Float>
}
