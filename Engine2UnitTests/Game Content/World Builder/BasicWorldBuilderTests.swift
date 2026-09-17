import Testing
import simd
@testable import Engine2

struct BasicWorldBuilderTests {
    private static let expectedEntityIDs = (0..<6).map {
        EntityID(index: $0, generation: 0)
    }

    private static let expectedPositions = [
        SIMD3<Double>(-1.75, 1.10, 0),
        SIMD3<Double>(0, 1.10, 0),
        SIMD3<Double>(1.75, 1.10, 0),
        SIMD3<Double>(-1.75, -1.10, 0),
        SIMD3<Double>(0, -1.10, 0),
        SIMD3<Double>(1.75, -1.10, 0)
    ]

    private static let expectedMaterialIDs: [MaterialID] = [
        .warmDielectricSmooth,
        .warmDielectric,
        .warmDielectricRough,
        .goldMetalSmooth,
        .goldMetal,
        .goldMetalRough
    ]

    private static let identityRotation = simd_quatf.identity

    @Test func seedsDeterministicMaterialSphereScene() {
        let world = BasicWorldBuilder().buildWorld()

        expectExactStoreMembership(in: world)
        #expect(
            world.components[PositionComponent.self].dense.map(\.position) ==
                Self.expectedPositions
        )
        #expect(
            world.components[RenderableComponent.self].dense.map(\.materialID) ==
                Self.expectedMaterialIDs
        )
        #expect(
            world.components[RenderableComponent.self].dense.map(\.meshID) ==
                Array(repeating: MeshID.ball, count: Self.expectedEntityIDs.count)
        )
        #expect(world.components[ScaleComponent.self].entities.isEmpty)
        #expect(world.components[ScaleComponent.self].dense.isEmpty)
        expectReferenceCamera(world.camera)

        expectQuiescentState(in: world)
    }

    @Test func materialSphereSceneRemainsQuiescentAcrossFixedSteps() {
        let initialWorld = BasicWorldBuilder().buildWorld()
        let sessionID = SimulationSessionID()
        let initialCursor = SimulationCursor(
            sessionID: sessionID,
            tick: .zero
        )
        let initialSnapshot = initialWorld.presentationSnapshot(
            at: initialCursor
        )
        let engine = Engine(
            world: initialWorld,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: .basicGame
        )

        // Exercise the actual invariant schedule long enough for any unintended
        // velocity, persistent acceleration, impulse, or angular drift to show.
        for _ in 0..<120 {
            engine.step()
        }

        let laterCursor = SimulationCursor(
            sessionID: sessionID,
            tick: engine.completedTick
        )
        let laterSnapshot = engine.world.presentationSnapshot(
            at: laterCursor
        )

        #expect(engine.completedTick == SimulationTick(rawValue: 120))
        #expect(
            laterSnapshot.entityPresentations ==
                initialSnapshot.entityPresentations
        )
        expectReferenceCamera(engine.world.camera)
        expectExactStoreMembership(in: engine.world)
        expectQuiescentState(in: engine.world)
    }

    /// Locks dense-store order to ordinary Ball registration order.
    private func expectExactStoreMembership(in world: World) {
        #expect(world.components[PositionComponent.self].entities == Self.expectedEntityIDs)
        #expect(world.components[MotionComponent.self].entities == Self.expectedEntityIDs)
        #expect(world.components[RotationComponent.self].entities == Self.expectedEntityIDs)
        #expect(world.components[AngularVelocityComponent.self].entities == Self.expectedEntityIDs)
        #expect(
            world.components[AngularMotionAccumulatorComponent.self].entities ==
                Self.expectedEntityIDs
        )
        #expect(world.components[RenderableComponent.self].entities == Self.expectedEntityIDs)
        #expect(world.components[SelectableComponent.self].entities == Self.expectedEntityIDs)
        #expect(world.components[ScaleComponent.self].entities.isEmpty)

        #expect(world.components[PositionComponent.self].dense.count == Self.expectedEntityIDs.count)
        #expect(world.components[MotionComponent.self].dense.count == Self.expectedEntityIDs.count)
        #expect(world.components[RotationComponent.self].dense.count == Self.expectedEntityIDs.count)
        #expect(
            world.components[AngularVelocityComponent.self].dense.count ==
                Self.expectedEntityIDs.count
        )
        #expect(
            world.components[AngularMotionAccumulatorComponent.self].dense.count ==
                Self.expectedEntityIDs.count
        )
        #expect(world.components[RenderableComponent.self].dense.count == Self.expectedEntityIDs.count)
        #expect(world.components[SelectableComponent.self].dense.count == Self.expectedEntityIDs.count)
        #expect(world.components[ScaleComponent.self].dense.isEmpty)
    }

    /// Verifies that ordinary movement-capable Balls are quiescent by state.
    private func expectQuiescentState(in world: World) {
        for entity in Self.expectedEntityIDs {
            #expect(world.components[MotionComponent.self][entity]?.velocity == .zero)
            #expect(world.components[MotionComponent.self][entity]?.accelerationIntent == .idle)
            #expect(world.components[MotionComponent.self][entity]?.acceleration == .zero)
            #expect(world.components[MotionComponent.self][entity]?.impulse == .zero)
            #expect(
                world.components[RotationComponent.self][entity]?.rotation.vector ==
                    Self.identityRotation.vector
            )
            #expect(world.components[AngularVelocityComponent.self][entity]?.angularVelocity == .zero)
            #expect(
                world.components[AngularMotionAccumulatorComponent.self][entity]?
                    .angularAcceleration == .zero
            )
            #expect(
                world.components[AngularMotionAccumulatorComponent.self][entity]?
                    .angularImpulse == .zero
            )
            #expect(
                world.components[SelectableComponent.self][entity]?.selectionState == .unselected
            )
        }
    }

    /// Freezes the independently documented M5 camera rather than asking the
    /// named production standard to serve as its own test expectation.
    private func expectReferenceCamera(_ camera: Camera) {
        #expect(camera.position == SIMD3<Float>(0, 0, 8))
        #expect(camera.rotation.vector == Self.identityRotation.vector)

        switch camera.projection {
        case let .perspective(verticalFieldOfView, near, far):
            #expect(verticalFieldOfView == Float.pi / 3)
            #expect(near == 0.1)
            #expect(far == 100)

        case .orthographic:
            Issue.record("The M5 reference camera must remain perspective.")
        }
    }
}
