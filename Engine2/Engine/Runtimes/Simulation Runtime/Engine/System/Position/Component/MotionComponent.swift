/// Translational motion state for movable entities.
///
/// `velocity` is integrated state, `accelerationIntent` is persistent drive
/// state, and `accumulator` is interval-local contribution input consumed by
/// `MovementSystem`. Translational values use double-precision SI units.
struct MotionComponent: Component {
    var accelerationIntent: AccelerationIntent {
        didSet {
            if accelerationIntent == .idle {
                accumulator.acceleration = .zero
            }
        }
    }
    var accumulator: Accumulator
    var velocity: SIMD3<Double>

    var acceleration: SIMD3<Double> {
        accumulator.acceleration
    }

    var impulse: SIMD3<Double> {
        accumulator.impulse
    }

    /// Creates motion state while normalizing accumulated acceleration to zero.
    ///
    /// Velocity, intent, and impulse defaults are neutral per-entity seeds. Persistent
    /// acceleration intent first contributes through `AccelerationIntentSystem`, preserving
    /// the invariant that the accumulator contains only work emitted for the next
    /// movement invocation.
    init(
        velocity: SIMD3<Double> = .zero,
        accelerationIntent: AccelerationIntent = .idle,
        impulse: SIMD3<Double> = .zero
    ) {
        self.velocity = velocity
        self.accelerationIntent = accelerationIntent
        self.accumulator = Accumulator(
            acceleration: .zero,
            impulse: impulse
        )
    }

    /// Aggregate translational contributions waiting for the next movement invocation.
    ///
    /// Acceleration is continuous and scales with the invocation interval;
    /// impulse is instantaneous and changes velocity without time scaling.
    struct Accumulator: Codable, Equatable {
        static let zero = Accumulator(acceleration: .zero, impulse: .zero)

        var acceleration: SIMD3<Double>
        var impulse: SIMD3<Double>
    }

    /// Persistent drive decision converted into accumulator input when `AccelerationIntentSystem` runs.
    ///
    /// Intent survives movement integration, unlike transient contributions,
    /// and therefore models states such as sustained thrust without allowing
    /// gameplay code to overwrite integrated velocity directly.
    enum AccelerationIntent: Codable, Equatable {
        case idle
        case accelerating(SIMD3<Double>)
    }
}

extension MotionComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (
                state.velocity == nil &&
                state.accelerationIntent == nil &&
                state.impulse == nil
            ) || entity is Movable,
            "Initial movement state requires Movable conformance"
        )
        guard entity is Movable else {
            return nil
        }

        self.init(
            velocity: state.velocity ?? .zero,
            accelerationIntent: state.accelerationIntent ?? .idle,
            impulse: state.impulse ?? .zero
        )
    }
}
