import simd
import Testing
@testable import Engine2

struct RenderFrameTests {
    @Test func projectionCreatesInstancesFromPublishedPresentationFacts() async throws {
        let world = World()
        let tick = SimulationTick(rawValue: 7)
        let cursor = cursor(at: tick)
        let first = EntityID(index: 0, generation: 0)
        let second = EntityID(index: 1, generation: 0)

        let firstPosition = SIMD3<Double>(2, -4, 0)
        world.positionComponents.insert(
            PositionComponent(position: firstPosition),
            for: first
        )
        let secondPosition = SIMD3<Double>(-1, 3, 0)
        world.positionComponents.insert(
            PositionComponent(position: secondPosition),
            for: second
        )
        world.renderableComponents.insert(
            RenderableComponent(meshID: .ball, materialID: .warmDielectric),
            for: first
        )
        world.renderableComponents.insert(
            RenderableComponent(meshID: .ball, materialID: .goldMetal),
            for: second
        )

        let snapshot = world.presentationSnapshot(at: cursor)
        let frame = RenderFrame(projecting: snapshot)

        #expect(frame.provenance == .simulation(sourceCursor: cursor))
        #expect(frame.sourceCursor == cursor)
        #expect(frame.sourceCursor?.tick == tick)
        #expect(frame.instances.map(\.meshID) == [.ball, .ball])
        #expect(frame.instances.map(\.materialID) == [.warmDielectric, .goldMetal])
        let expectedTransforms = [
            Transform(
                position: firstPosition.singlePrecision,
                rotation: .identity,
                scale: RenderInstance.defaultScale
            ),
            Transform(
                position: secondPosition.singlePrecision,
                rotation: .identity,
                scale: RenderInstance.defaultScale
            )
        ]
        #expect(frame.instances.map(\.transform) == expectedTransforms)
        for instance in frame.instances {
            #expect(
                instance.modelViewMatrix
                    == frame.camera.viewMatrix * instance.transform.matrix
            )
        }
    }

    @Test func projectionDetachesMaterialIdentityFromLaterECSMutation() throws {
        let world = World()
        let sessionID = SimulationSessionID()
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(PositionComponent(position: .zero), for: entity)
        world.renderableComponents.insert(
            RenderableComponent(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )

        let snapshot = world.presentationSnapshot(
            at: SimulationCursor(sessionID: sessionID, tick: .zero)
        )
        let frame = RenderFrame(projecting: snapshot)
        let didUpdateMaterial = world.renderableComponents.update(for: entity) {
            $0.materialID = .goldMetal
        }
        let snapshotEntity = try #require(
            snapshot.entityPresentations.first
        )
        let frameInstance = try #require(frame.instances.first)
        let laterSnapshot = world.presentationSnapshot(
            at: SimulationCursor(
                sessionID: sessionID,
                tick: SimulationTick(rawValue: 1)
            )
        )
        let laterEntity = try #require(laterSnapshot.entityPresentations.first)

        #expect(didUpdateMaterial)
        #expect(snapshotEntity.materialID == .warmDielectric)
        #expect(frameInstance.materialID == .warmDielectric)
        #expect(laterEntity.materialID == .goldMetal)
    }

    @Test func projectionIgnoresPositionedEntitiesWithoutPresentationContent() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.positionComponents.insert(
            PositionComponent(position: SIMD3<Double>(2, -4, 0)),
            for: entity
        )

        let snapshot = world.presentationSnapshot(at: cursor())

        #expect(snapshot.entityPresentations.isEmpty)
        #expect(RenderFrame(projecting: snapshot).instances.isEmpty)
    }

    @Test func projectionIgnoresRenderableEntitiesWithoutPositions() {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        world.renderableComponents.insert(
            RenderableComponent(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )

        let snapshot = world.presentationSnapshot(at: cursor())

        #expect(snapshot.entityPresentations.map(\.id) == [entity])
        #expect(RenderFrame(projecting: snapshot).instances.isEmpty)
    }

    @Test func projectionIncludesCameraRotationAndScale() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        let rotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))
        let scale = SIMD3<Float>(2, 3, 4)

        world.camera = Camera(
            position: SIMD3<Float>(1, 2, 3),
            rotation: .identity,
            projection: .orthographic(
                height: 12,
                near: 0.1,
                far: 100
            )
        )
        let position = SIMD3<Double>(3, 4, 5)
        world.positionComponents.insert(PositionComponent(position: position), for: entity)
        world.renderableComponents.insert(
            RenderableComponent(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        world.rotationComponents.insert(RotationComponent(rotation: rotation), for: entity)
        world.scaleComponents.insert(ScaleComponent(scale: scale), for: entity)

        let snapshot = world.presentationSnapshot(at: cursor())
        let frame = RenderFrame(projecting: snapshot)

        #expect(frame.camera == world.camera)
        let instance = try #require(frame.instances.first)
        #expect(frame.instances.count == 1)
        #expect(instance.meshID == .ball)
        #expect(instance.materialID == .warmDielectric)
        let expectedTransform = Transform(
            position: position.singlePrecision,
            rotation: rotation,
            scale: scale
        )
        #expect(instance.transform == expectedTransform)
        #expect(
            instance.modelViewMatrix
                == frame.camera.viewMatrix * instance.transform.matrix
        )
    }

    @Test func projectionOmitsTransformsThatCannotProduceFiniteNormals() {
        let world = World()
        let zeroScaleEntity = EntityID(index: 0, generation: 0)
        let nonfinitePositionEntity = EntityID(index: 1, generation: 0)

        for entity in [zeroScaleEntity, nonfinitePositionEntity] {
            world.renderableComponents.insert(
                RenderableComponent(meshID: .ball, materialID: .warmDielectric),
                for: entity
            )
        }
        world.positionComponents.insert(
            PositionComponent(position: .zero),
            for: zeroScaleEntity
        )
        world.scaleComponents.insert(
            ScaleComponent(scale: SIMD3<Float>(1, 0, 1)),
            for: zeroScaleEntity
        )
        world.positionComponents.insert(
            PositionComponent(position: SIMD3<Double>(.nan, 0, 0)),
            for: nonfinitePositionEntity
        )

        let snapshot = world.presentationSnapshot(at: cursor())

        #expect(snapshot.entityPresentations.count == 2)
        #expect(RenderFrame(projecting: snapshot).instances.isEmpty)
    }

    @Test func projectionProducesNoInstancesForAnInvalidCameraTransform() {
        let world = World()
        let tick = SimulationTick(rawValue: 3)
        let cursor = cursor(at: tick)
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(PositionComponent(position: .zero), for: entity)
        world.renderableComponents.insert(
            RenderableComponent(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        world.camera.position = SIMD3<Float>(.infinity, 0, 8)

        let snapshot = world.presentationSnapshot(at: cursor)
        let frame = RenderFrame(projecting: snapshot)

        #expect(frame.sourceCursor == cursor)
        #expect(frame.sourceCursor?.tick == tick)
        #expect(frame.camera == snapshot.camera)
        #expect(frame.instances.isEmpty)
    }

    @Test func projectionOmitsFiniteTransformsWhoseCombinationOverflows() {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(
            PositionComponent(
                position: SIMD3<Double>(Double(Float.greatestFiniteMagnitude), 0, 0)
            ),
            for: entity
        )
        world.renderableComponents.insert(
            RenderableComponent(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        world.camera = Camera(
            position: SIMD3<Float>(-.greatestFiniteMagnitude, 0, 0),
            rotation: .identity,
            projection: .standardPerspective
        )

        let snapshot = world.presentationSnapshot(at: cursor())

        #expect(snapshot.camera.supportsViewTransform)
        #expect(RenderFrame(projecting: snapshot).instances.isEmpty)
    }

    @Test func emptyFrameDoesNotFabricateSimulationProvenance() {
        #expect(RenderFrame.empty.provenance == .empty)
        #expect(RenderFrame.empty.sourceCursor == nil)
        #expect(RenderFrame.empty.sourceCursor?.tick == nil)
    }

    private func cursor(at tick: SimulationTick = .zero) -> SimulationCursor {
        SimulationCursor(sessionID: SimulationSessionID(), tick: tick)
    }
}
