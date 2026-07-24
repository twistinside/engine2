import Testing
import simd
@testable import Engine2

@MainActor
struct BasicWorldBuilderTests {
    @Test func seedsDeterministicMaterialSphereScene() {
        let world = BasicWorldBuilder().buildWorld()

        expectExactStoreMembership(in: world)
        #expect(
            world.positionComponents.dense.map(\.position) ==
                Self.expectedPositions
        )
        #expect(
            world.renderableComponents.dense.map(\.materialID) ==
                Self.expectedMaterialIDs
        )
        #expect(
            world.renderableComponents.dense.map(\.meshID) ==
                Array(repeating: MeshID.ball, count: Self.expectedEntityIDs.count)
        )
        #expect(world.scaleComponents.entities.isEmpty)
        #expect(world.scaleComponents.dense.isEmpty)
        expectReferenceCamera(world.camera)

        expectQuiescentState(in: world)
    }

    @Test func materialSphereSceneRemainsQuiescentAcrossFixedSteps() {
        let initialWorld = BasicWorldBuilder().buildWorld()
        let sessionID = SimulationSessionID()
        let initialSnapshot = initialWorld.presentationSnapshot(
            at: SimulationCursor(sessionID: sessionID, tick: .zero)
        )
        let engine = Engine(
            world: initialWorld,
            fixedTimeStep: SimulationRuntime.fixedTimeStep
        )

        // Exercise the actual invariant schedule long enough for any unintended
        // velocity, persistent acceleration, impulse, or angular drift to show.
        for _ in 0..<120 {
            engine.step()
        }

        let laterSnapshot = engine.world.presentationSnapshot(
            at: SimulationCursor(
                sessionID: sessionID,
                tick: engine.completedTick
            )
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
        #expect(world.positionComponents.entities == Self.expectedEntityIDs)
        #expect(world.motionComponents.entities == Self.expectedEntityIDs)
        #expect(world.rotationComponents.entities == Self.expectedEntityIDs)
        #expect(world.angularVelocityComponents.entities == Self.expectedEntityIDs)
        #expect(
            world.angularMotionAccumulatorComponents.entities ==
                Self.expectedEntityIDs
        )
        #expect(world.renderableComponents.entities == Self.expectedEntityIDs)
        #expect(world.selectableComponents.entities == Self.expectedEntityIDs)
        #expect(world.scaleComponents.entities.isEmpty)

        #expect(world.positionComponents.dense.count == Self.expectedEntityIDs.count)
        #expect(world.motionComponents.dense.count == Self.expectedEntityIDs.count)
        #expect(world.rotationComponents.dense.count == Self.expectedEntityIDs.count)
        #expect(
            world.angularVelocityComponents.dense.count ==
                Self.expectedEntityIDs.count
        )
        #expect(
            world.angularMotionAccumulatorComponents.dense.count ==
                Self.expectedEntityIDs.count
        )
        #expect(world.renderableComponents.dense.count == Self.expectedEntityIDs.count)
        #expect(world.selectableComponents.dense.count == Self.expectedEntityIDs.count)
        #expect(world.scaleComponents.dense.isEmpty)
    }

    /// Verifies that ordinary movement-capable Balls are quiescent by state.
    private func expectQuiescentState(in world: World) {
        for entity in Self.expectedEntityIDs {
            #expect(world.motionComponents[entity]?.velocity == .zero)
            #expect(world.motionComponents[entity]?.accelerationIntent == .idle)
            #expect(world.motionComponents[entity]?.acceleration == .zero)
            #expect(world.motionComponents[entity]?.impulse == .zero)
            #expect(
                world.rotationComponents[entity]?.rotation.vector ==
                    Self.identityRotation.vector
            )
            #expect(world.angularVelocityComponents[entity]?.angularVelocity == .zero)
            #expect(
                world.angularMotionAccumulatorComponents[entity]?
                    .angularAcceleration == .zero
            )
            #expect(
                world.angularMotionAccumulatorComponents[entity]?
                    .angularImpulse == .zero
            )
            #expect(
                world.selectableComponents[entity]?.selectionState == .unselected
            )
        }
    }

    /// Freezes the independently documented M5 camera instead of asking the
    /// mutable production defaults to serve as their own test expectation.
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

    private static let expectedEntityIDs = (0..<6).map {
        EntityID(index: $0, generation: 0)
    }

    private static let expectedPositions = [
        SIMD3<Float>(-1.75, 1.10, 0),
        SIMD3<Float>(0, 1.10, 0),
        SIMD3<Float>(1.75, 1.10, 0),
        SIMD3<Float>(-1.75, -1.10, 0),
        SIMD3<Float>(0, -1.10, 0),
        SIMD3<Float>(1.75, -1.10, 0)
    ]

    private static let expectedMaterialIDs: [MaterialID] = [
        .warmDielectricSmooth,
        .warmDielectric,
        .warmDielectricRough,
        .goldMetalSmooth,
        .goldMetal,
        .goldMetalRough
    ]

    private static let identityRotation = simd_quatf(
        angle: 0,
        axis: SIMD3<Float>(0, 0, 1)
    )
}
