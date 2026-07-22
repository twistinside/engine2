import simd
import Testing
@testable import Engine2

struct RenderFrameTests {
    @Test func projectionCreatesInstancesFromPublishedPresentationFacts() async throws {
        let world = World()
        let cursor = Self.cursor(at: SimulationTick(rawValue: 7))
        let first = EntityID(index: 0, generation: 0)
        let second = EntityID(index: 1, generation: 0)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(2, -4, 0)), for: first)
        world.positionComponents.insert(CPosition(position: SIMD3<Float>(-1, 3, 0)), for: second)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: first
        )
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .goldMetal),
            for: second
        )

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: cursor
        )
        let frame = RenderFrame.project(from: snapshot)

        #expect(frame.sourceCursor == cursor)
        #expect(frame.sourceTick == SimulationTick(rawValue: 7))
        #expect(frame.viewpointID == nil)
        #expect(frame.viewpointRevision == nil)
        #expect(
            frame.instances == [
                RenderInstance(
                    meshID: .ball,
                    materialID: .warmDielectric,
                    worldPosition: SIMD3<Float>(2, -4, 0)
                ),
                RenderInstance(
                    meshID: .ball,
                    materialID: .goldMetal,
                    worldPosition: SIMD3<Float>(-1, 3, 0)
                )
            ]
        )
    }

    @Test func projectionDetachesMaterialIdentityFromLaterECSMutation() throws {
        let world = World()
        let sessionID = SimulationSessionID()
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(CPosition(position: .zero), for: entity)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: SimulationCursor(sessionID: sessionID, tick: .zero)
        )
        let frame = RenderFrame.project(from: snapshot)
        let didUpdateMaterial = world.renderableComponents.update(for: entity) {
            $0.materialID = .goldMetal
        }
        let snapshotEntity = try #require(
            snapshot.entityPresentations.first
        )
        let frameInstance = try #require(frame.instances.first)
        let laterEntity = try #require(
            SimulationPresentationSnapshot.capture(
                from: world,
                at: SimulationCursor(
                    sessionID: sessionID,
                    tick: SimulationTick(rawValue: 1)
                )
            ).entityPresentations.first
        )

        #expect(didUpdateMaterial)
        #expect(snapshotEntity.materialID == .warmDielectric)
        #expect(frameInstance.materialID == .warmDielectric)
        #expect(laterEntity.materialID == .goldMetal)
    }

    @Test func projectionIgnoresPositionedEntitiesWithoutPresentationContent() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(2, -4, 0)), for: entity)

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: Self.cursor()
        )

        #expect(snapshot.entityPresentations.isEmpty)
        #expect(RenderFrame.project(from: snapshot).instances.isEmpty)
    }

    @Test func projectionIgnoresRenderableEntitiesWithoutPositions() {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: Self.cursor()
        )

        #expect(snapshot.entityPresentations.map(\.id) == [entity])
        #expect(RenderFrame.project(from: snapshot).instances.isEmpty)
    }

    @Test func projectionIncludesCameraRotationAndScale() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        let rotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))
        let scale = SIMD3<Float>(2, 3, 4)

        world.camera = Camera(position: SIMD3<Float>(1, 2, 3), orthographicHeight: 12)
        world.positionComponents.insert(CPosition(position: SIMD3<Float>(3, 4, 5)), for: entity)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        world.rotationComponents.insert(CRotation(rotation: rotation), for: entity)
        world.scaleComponents.insert(CScale(scale: scale), for: entity)

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: Self.cursor()
        )
        let frame = RenderFrame.project(from: snapshot)

        #expect(frame.camera == world.camera)
        #expect(frame.viewpointID == nil)
        #expect(frame.viewpointRevision == nil)
        #expect(
            frame.instances == [
                RenderInstance(
                    meshID: .ball,
                    materialID: .warmDielectric,
                    transform: Transform(
                        position: SIMD3<Float>(3, 4, 5),
                        rotation: rotation,
                        scale: scale
                    )
                )
            ]
        )
    }

    @Test func projectionCanApplyDistinctExplicitViewpointsToTheSameSnapshot() {
        let world = World()
        let cursor = Self.cursor(at: SimulationTick(rawValue: 11))
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(
            CPosition(position: SIMD3<Float>(2, 3, 4)),
            for: entity
        )
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .goldMetal),
            for: entity
        )

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: cursor
        )
        let firstViewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: RenderViewpointRevision(rawValue: 2),
            camera: Camera(position: SIMD3<Float>(0, 0, 6))
        )
        let secondViewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: RenderViewpointRevision(rawValue: 9),
            camera: Camera(position: SIMD3<Float>(6, 2, 0))
        )

        let firstFrame = RenderFrame.project(
            from: snapshot,
            viewpoint: firstViewpoint
        )
        let secondFrame = RenderFrame.project(
            from: snapshot,
            viewpoint: secondViewpoint
        )

        #expect(firstFrame.sourceCursor == cursor)
        #expect(secondFrame.sourceCursor == cursor)
        #expect(firstFrame.instances == secondFrame.instances)
        #expect(firstFrame.camera == firstViewpoint.camera)
        #expect(secondFrame.camera == secondViewpoint.camera)
        #expect(firstFrame.camera != secondFrame.camera)
        #expect(firstFrame.viewpointID == firstViewpoint.id)
        #expect(secondFrame.viewpointID == secondViewpoint.id)
        #expect(firstFrame.viewpointID != secondFrame.viewpointID)
        #expect(firstFrame.viewpointRevision == firstViewpoint.revision)
        #expect(secondFrame.viewpointRevision == secondViewpoint.revision)
        #expect(firstFrame.viewpointRevision != secondFrame.viewpointRevision)
    }

    @Test func projectionOmitsTransformsThatCannotProduceFiniteNormals() {
        let world = World()
        let zeroScaleEntity = EntityID(index: 0, generation: 0)
        let nonfinitePositionEntity = EntityID(index: 1, generation: 0)

        for entity in [zeroScaleEntity, nonfinitePositionEntity] {
            world.renderableComponents.insert(
                CRenderable(meshID: .ball, materialID: .warmDielectric),
                for: entity
            )
        }
        world.positionComponents.insert(
            CPosition(position: .zero),
            for: zeroScaleEntity
        )
        world.scaleComponents.insert(
            CScale(scale: SIMD3<Float>(1, 0, 1)),
            for: zeroScaleEntity
        )
        world.positionComponents.insert(
            CPosition(position: SIMD3<Float>(.nan, 0, 0)),
            for: nonfinitePositionEntity
        )

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: Self.cursor()
        )

        #expect(snapshot.entityPresentations.count == 2)
        #expect(RenderFrame.project(from: snapshot).instances.isEmpty)
    }

    @Test func projectionProducesNoInstancesForAnInvalidCameraTransform() {
        let world = World()
        let cursor = Self.cursor(at: SimulationTick(rawValue: 3))
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(CPosition(position: .zero), for: entity)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        world.camera.position = SIMD3<Float>(.infinity, 0, 8)

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: cursor
        )
        let frame = RenderFrame.project(from: snapshot)

        #expect(frame.sourceCursor == cursor)
        #expect(frame.sourceTick == SimulationTick(rawValue: 3))
        #expect(frame.camera == snapshot.camera)
        #expect(frame.instances.isEmpty)
    }

    @Test func invalidExplicitViewpointProducesAnAttributedEmptyFrame() {
        let world = World()
        let cursor = Self.cursor(at: SimulationTick(rawValue: 5))
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(CPosition(position: .zero), for: entity)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: cursor
        )
        var invalidCamera = Camera()
        invalidCamera.position = SIMD3<Float>(.infinity, 0, 8)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: RenderViewpointRevision(rawValue: 4),
            camera: invalidCamera
        )

        let frame = RenderFrame.project(
            from: snapshot,
            viewpoint: viewpoint
        )

        #expect(frame.sourceCursor == cursor)
        #expect(frame.viewpointID == viewpoint.id)
        #expect(frame.viewpointRevision == viewpoint.revision)
        #expect(frame.camera == invalidCamera)
        #expect(frame.instances.isEmpty)
    }

    @Test func projectionOmitsFiniteTransformsWhoseCombinationOverflows() {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(
            CPosition(
                position: SIMD3<Float>(.greatestFiniteMagnitude, 0, 0)
            ),
            for: entity
        )
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        world.camera = Camera(
            position: SIMD3<Float>(-.greatestFiniteMagnitude, 0, 0)
        )

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: Self.cursor()
        )

        #expect(snapshot.camera.supportsViewTransform)
        #expect(RenderFrame.project(from: snapshot).instances.isEmpty)
    }

    @Test func emptyFrameDoesNotFabricateSimulationProvenance() {
        #expect(RenderFrame.empty.sourceCursor == nil)
        #expect(RenderFrame.empty.sourceTick == nil)
        #expect(RenderFrame.empty.viewpointID == nil)
        #expect(RenderFrame.empty.viewpointRevision == nil)
    }

    private static func cursor(
        at tick: SimulationTick = .zero
    ) -> SimulationCursor {
        SimulationCursor(sessionID: SimulationSessionID(), tick: tick)
    }
}
