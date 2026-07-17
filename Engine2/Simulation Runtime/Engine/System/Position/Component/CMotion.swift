/// Translational motion state for movable entities.
///
/// `velocity` is integrated state, `accelerationIntent` is persistent drive
/// state, and `accumulator` is per-frame contribution input consumed by
/// `SMovement`.
struct CMotion: PComponent {
    var accelerationIntent: AccelerationIntent {
        didSet {
            if accelerationIntent == .idle {
                accumulator.acceleration = .zero
            }
        }
    }
    var accumulator: Accumulator
    var velocity: SIMD3<Float>

    var acceleration: SIMD3<Float> {
        accumulator.acceleration
    }

    var impulse: SIMD3<Float> {
        accumulator.impulse
    }

    init(
        velocity: SIMD3<Float> = .zero,
        accelerationIntent: AccelerationIntent = .idle,
        impulse: SIMD3<Float> = .zero
    ) {
        self.velocity = velocity
        self.accelerationIntent = accelerationIntent
        self.accumulator = Accumulator(
            acceleration: .zero,
            impulse: impulse
        )
    }

    /// Aggregate translational contributions waiting for movement integration.
    ///
    /// Acceleration is continuous and scales with the fixed-step duration;
    /// impulse is instantaneous and changes velocity without time scaling.
    struct Accumulator: Codable, Equatable {
        static let zero = Accumulator(acceleration: .zero, impulse: .zero)

        var acceleration: SIMD3<Float>
        var impulse: SIMD3<Float>
    }

    /// Persistent drive decision converted into accumulator input each tick.
    ///
    /// Intent survives movement integration, unlike transient contributions,
    /// and therefore models states such as sustained thrust without allowing
    /// gameplay code to overwrite integrated velocity directly.
    enum AccelerationIntent: Codable, Equatable {
        case idle
        case accelerating(SIMD3<Float>)
    }
}
