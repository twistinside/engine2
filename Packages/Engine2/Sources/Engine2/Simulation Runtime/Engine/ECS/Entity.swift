import simd

/// Stable, typed game-object facade over component state owned by a `World`.
///
/// An entity retains its generational identity and an unowned reference to the
/// world that stores its authoritative data. Capability protocols add live,
/// ergonomic accessors for game code and tooling; simulation systems should
/// iterate component stores directly instead of using entity objects in hot
/// paths.
open class Entity {
    public let id: EntityID
    public unowned let world: World

    /// Common optional values used to seed authoritative component rows.
    ///
    /// Only values shared by foundational engine capabilities belong here.
    /// Specialized Game Content should use concrete entity initializers,
    /// builders, or focused spawn helpers instead of growing this into a
    /// universal descriptor.
    public struct InitialState {
        static let empty = InitialState()

        // PPositionable
        var position: SIMD3<Float>? = nil

        // PMovable
        var velocity: SIMD3<Float>? = nil
        var accelerationIntent: CMotion.AccelerationIntent? = nil
        var impulse: SIMD3<Float>? = nil

        // POrientable
        var rotation: simd_quatf? = nil

        // PRotatable
        var angularVelocity: SIMD3<Float>? = nil
        var angularAcceleration: SIMD3<Float>? = nil
        var angularImpulse: SIMD3<Float>? = nil

        // PScalable
        var scale: SIMD3<Float>? = nil

        // PSelectable
        var selectionState: CSelectable.SelectionState? = nil

        public init(
            position: SIMD3<Float>? = nil,
            velocity: SIMD3<Float>? = nil,
            accelerationIntent: CMotion.AccelerationIntent? = nil,
            impulse: SIMD3<Float>? = nil,
            rotation: simd_quatf? = nil,
            angularVelocity: SIMD3<Float>? = nil,
            angularAcceleration: SIMD3<Float>? = nil,
            angularImpulse: SIMD3<Float>? = nil,
            scale: SIMD3<Float>? = nil,
            selectionState: CSelectable.SelectionState? = nil
        ) {
            self.position = position
            self.velocity = velocity
            self.accelerationIntent = accelerationIntent
            self.impulse = impulse
            self.rotation = rotation
            self.angularVelocity = angularVelocity
            self.angularAcceleration = angularAcceleration
            self.angularImpulse = angularImpulse
            self.scale = scale
            self.selectionState = selectionState
        }
    }

    /// Creates a live entity handle without registering it in the world.
    ///
    /// This entry point is for test fixtures and future reconstruction paths
    /// that need an entity wrapper before world registration occurs.
    init(unregisteredID id: EntityID, in world: World) {
        self.id = id
        self.world = world
    }

    /// Reserves one identity and atomically registers every advertised capability.
    ///
    /// External Game Content subclasses call this initializer only after their
    /// own stored state is initialized. The world retains no entity object; it
    /// creates the authoritative component rows selected by the dynamic
    /// capability conformances and the supplied seed values.
    public init(
        in world: World,
        from state: InitialState,
        renderable renderableState: RenderableInitialState?
    ) {
        self.id = world.reserveEntityID()
        self.world = world
        world.add(self, from: state, renderable: renderableState)
    }

    /// Reserves an ID and registers the fully initialized entity with the world.
    public convenience init(in world: World, from state: InitialState) {
        self.init(in: world, from: state, renderable: nil)
    }
}
