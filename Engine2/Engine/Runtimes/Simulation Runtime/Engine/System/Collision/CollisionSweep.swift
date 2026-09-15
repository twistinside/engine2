/// Captured planar geometry and lifetime interval for one active collision body.
///
/// CollisionSystem records the tick's original path and remaining lifetime before response or expiry.
/// CollisionResponseSystem adjusts a local copy of the endpoint after each positional correction;
/// the previous position and travel fraction remain the original tick baseline.
struct CollisionSweep {
    let entityID: EntityID
    let previousPosition: SIMD2<Double>
    var position: SIMD2<Double>
    let radius: Double
    let travelFraction: Double
}
