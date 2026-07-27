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

        let firstPosition = SIMD3<Float>(2, -4, 0)
        world.positionComponents.insert(CPosition(position: firstPosition), for: first)
        let secondPosition = SIMD3<Float>(-1, 3, 0)
        world.positionComponents.insert(CPosition(position: secondPosition), for: second)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: first
        )
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .goldMetal),
            for: second
        )

        let snapshot = world.presentationSnapshot(at: cursor)
        let frame = RenderFrame(projecting: snapshot)

        #expect(frame.provenance == .simulation(sourceCursor: cursor))
        #expect(frame.sourceCursor == cursor)
        #expect(frame.sourceTick == tick)
        #expect(frame.viewpointID == nil)
        #expect(frame.viewpointRevision == nil)
        #expect(frame.instances.map(\.meshID) == [.ball, .ball])
        #expect(frame.instances.map(\.materialID) == [.warmDielectric, .goldMetal])
        let expectedTransforms = [
            Transform(
                position: firstPosition,
                rotation: .identity,
                scale: RenderInstance.defaultScale
            ),
            Transform(
                position: secondPosition,
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
        world.positionComponents.insert(CPosition(position: .zero), for: entity)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
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

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(2, -4, 0)), for: entity)

        let snapshot = world.presentationSnapshot(at: cursor())

        #expect(snapshot.entityPresentations.isEmpty)
        #expect(RenderFrame(projecting: snapshot).instances.isEmpty)
    }

    @Test func projectionIgnoresRenderableEntitiesWithoutPositions() {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
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
        let position = SIMD3<Float>(3, 4, 5)
        world.positionComponents.insert(CPosition(position: position), for: entity)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        world.rotationComponents.insert(CRotation(rotation: rotation), for: entity)
        world.scaleComponents.insert(CScale(scale: scale), for: entity)

        let snapshot = world.presentationSnapshot(at: cursor())
        let frame = RenderFrame(projecting: snapshot)

        #expect(frame.camera == world.camera)
        #expect(frame.viewpointID == nil)
        #expect(frame.viewpointRevision == nil)
        let instance = try #require(frame.instances.first)
        #expect(frame.instances.count == 1)
        #expect(instance.meshID == .ball)
        #expect(instance.materialID == .warmDielectric)
        let expectedTransform = Transform(
            position: position,
            rotation: rotation,
            scale: scale
        )
        #expect(instance.transform == expectedTransform)
        #expect(
            instance.modelViewMatrix
                == frame.camera.viewMatrix * instance.transform.matrix
        )
    }

    @Test func exactProjectionCanApplyDistinctExplicitViewpointsToTheSameSnapshot() throws {
        let world = World()
        let cursor = cursor(at: SimulationTick(rawValue: 11))
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(
            CPosition(position: SIMD3<Float>(2, 3, 4)),
            for: entity
        )
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .goldMetal),
            for: entity
        )

        let snapshot = world.presentationSnapshot(at: cursor)
        let firstViewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: RenderViewpointRevision(rawValue: 2),
            camera: Camera(
                position: SIMD3<Float>(0, 0, 6),
                rotation: .identity,
                projection: .standardPerspective
            )
        )
        let secondViewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: RenderViewpointRevision(rawValue: 9),
            camera: Camera(
                position: SIMD3<Float>(6, 2, 0),
                rotation: .identity,
                projection: .standardPerspective
            )
        )

        let firstFrame = try RenderFrame(
            exactlyProjecting: snapshot,
            viewpoint: firstViewpoint
        )
        let secondFrame = try RenderFrame(
            exactlyProjecting: snapshot,
            viewpoint: secondViewpoint
        )

        #expect(
            firstFrame.provenance
                == .exact(
                    sourceCursor: cursor,
                    viewpointID: firstViewpoint.id,
                    viewpointRevision: firstViewpoint.revision
                )
        )
        #expect(
            secondFrame.provenance
                == .exact(
                    sourceCursor: cursor,
                    viewpointID: secondViewpoint.id,
                    viewpointRevision: secondViewpoint.revision
                )
        )
        #expect(firstFrame.sourceCursor == cursor)
        #expect(secondFrame.sourceCursor == cursor)
        let firstInstance = try #require(firstFrame.instances.first)
        let secondInstance = try #require(secondFrame.instances.first)
        #expect(firstFrame.instances.count == 1)
        #expect(secondFrame.instances.count == 1)
        #expect(firstInstance.transform == secondInstance.transform)
        #expect(firstInstance.modelViewMatrix != secondInstance.modelViewMatrix)
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

        let snapshot = world.presentationSnapshot(at: cursor())

        #expect(snapshot.entityPresentations.count == 2)
        #expect(RenderFrame(projecting: snapshot).instances.isEmpty)
    }

    @Test func projectionProducesNoInstancesForAnInvalidCameraTransform() {
        let world = World()
        let tick = SimulationTick(rawValue: 3)
        let cursor = cursor(at: tick)
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(CPosition(position: .zero), for: entity)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        world.camera.position = SIMD3<Float>(.infinity, 0, 8)

        let snapshot = world.presentationSnapshot(at: cursor)
        let frame = RenderFrame(projecting: snapshot)

        #expect(frame.sourceCursor == cursor)
        #expect(frame.sourceTick == tick)
        #expect(frame.camera == snapshot.camera)
        #expect(frame.instances.isEmpty)
    }

    @Test func exactProjectionRejectsAnInvalidSelectedCamera() {
        let world = World()
        let snapshot = world.presentationSnapshot(at: cursor())
        var camera = Camera.standard
        camera.position = SIMD3<Float>(.infinity, 0, 8)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: camera
        )

        #expect(throws: RenderFrameProjectionError.invalidSelectedCamera) {
            try RenderFrame(
                exactlyProjecting: snapshot,
                viewpoint: viewpoint
            )
        }
    }

    @Test func exactProjectionPreservesTheCompleteValidProjection() throws {
        let world = World()
        let cursor = cursor(at: SimulationTick(rawValue: 13))
        let entity = EntityID(index: 5, generation: 1)
        let position = SIMD3<Float>(1, 2, 3)
        world.positionComponents.insert(
            CPosition(position: position),
            for: entity
        )
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .goldMetal),
            for: entity
        )
        let snapshot = world.presentationSnapshot(at: cursor)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: RenderViewpointRevision(rawValue: 6),
            camera: Camera(
                position: SIMD3<Float>(0, 0, 10),
                rotation: .identity,
                projection: .standardPerspective
            )
        )

        let exact = try RenderFrame(
            exactlyProjecting: snapshot,
            viewpoint: viewpoint
        )

        #expect(exact.sourceCursor == cursor)
        #expect(exact.camera == viewpoint.camera)
        #expect(exact.viewpointID == viewpoint.id)
        #expect(exact.viewpointRevision == viewpoint.revision)
        let instance = try #require(exact.instances.first)
        #expect(exact.instances.count == 1)
        #expect(instance.meshID == .ball)
        #expect(instance.materialID == .goldMetal)
        let expectedTransform = Transform(
            position: position,
            rotation: .identity,
            scale: RenderInstance.defaultScale
        )
        #expect(instance.transform == expectedTransform)
        #expect(
            instance.modelViewMatrix
                == viewpoint.camera.viewMatrix * instance.transform.matrix
        )
    }

    @Test func exactProjectionIdentifiesAnEntityWithoutPosition() {
        let world = World()
        let entity = EntityID(index: 17, generation: 3)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        let snapshot = world.presentationSnapshot(at: cursor())

        #expect(
            throws: RenderFrameProjectionError.missingPosition(
                entityID: entity
            )
        ) {
            try RenderFrame(
                exactlyProjecting: snapshot,
                viewpoint: viewpoint(camera: .standard)
            )
        }
    }

    @Test func exactProjectionIdentifiesAnUnsupportedNormalTransform() {
        let world = World()
        let entity = EntityID(index: 23, generation: 4)
        world.positionComponents.insert(CPosition(position: .zero), for: entity)
        world.scaleComponents.insert(
            CScale(scale: SIMD3<Float>(1, 0, 1)),
            for: entity
        )
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        let snapshot = world.presentationSnapshot(at: cursor())

        #expect(
            throws: RenderFrameProjectionError.unsupportedNormalTransform(
                entityID: entity
            )
        ) {
            try RenderFrame(
                exactlyProjecting: snapshot,
                viewpoint: viewpoint(camera: .standard)
            )
        }
    }

    @Test func exactProjectionRejectsANormalMatrixThatUnderflows() {
        let world = World()
        let entity = EntityID(index: 24, generation: 4)
        world.positionComponents.insert(CPosition(position: .zero), for: entity)
        world.scaleComponents.insert(
            CScale(scale: SIMD3<Float>(repeating: 1e-20)),
            for: entity
        )
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        let snapshot = world.presentationSnapshot(at: cursor())

        #expect(
            throws: RenderFrameProjectionError.unsupportedNormalTransform(
                entityID: entity
            )
        ) {
            try RenderFrame(
                exactlyProjecting: snapshot,
                viewpoint: viewpoint(camera: .standard)
            )
        }
    }

    @Test func exactProjectionIdentifiesNonfiniteCombinedModelViewTransform() {
        let world = World()
        let entity = EntityID(index: 29, generation: 5)
        world.positionComponents.insert(
            CPosition(position: SIMD3<Float>(.greatestFiniteMagnitude, 0, 0)),
            for: entity
        )
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
            for: entity
        )
        let snapshot = world.presentationSnapshot(at: cursor())
        let viewpoint = viewpoint(
            camera: Camera(
                position: SIMD3<Float>(-.greatestFiniteMagnitude, 0, 0),
                rotation: .identity,
                projection: .standardPerspective
            )
        )

        #expect(
            throws: RenderFrameProjectionError.nonfiniteModelViewTransform(
                entityID: entity
            )
        ) {
            try RenderFrame(
                exactlyProjecting: snapshot,
                viewpoint: viewpoint
            )
        }
    }

    @Test func projectionOmitsFiniteTransformsWhoseCombinationOverflows() {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        world.positionComponents.insert(
            CPosition(position: SIMD3<Float>(.greatestFiniteMagnitude, 0, 0)),
            for: entity
        )
        world.renderableComponents.insert(
            CRenderable(meshID: .ball, materialID: .warmDielectric),
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
        #expect(RenderFrame.empty.sourceTick == nil)
        #expect(RenderFrame.empty.viewpointID == nil)
        #expect(RenderFrame.empty.viewpointRevision == nil)
    }

    private func cursor(at tick: SimulationTick = .zero) -> SimulationCursor {
        SimulationCursor(sessionID: SimulationSessionID(), tick: tick)
    }

    private func viewpoint(camera: Camera) -> RenderViewpoint {
        RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: camera
        )
    }
}
