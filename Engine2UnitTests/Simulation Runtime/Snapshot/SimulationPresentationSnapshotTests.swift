import Testing
import simd
@testable import Engine2

struct SimulationPresentationSnapshotTests {
    private static let meshKey = MeshAssetKey(rawValue: 7)
    private static let firstMaterialKey = MaterialAssetKey(rawValue: 11)
    private static let secondMaterialKey = MaterialAssetKey(rawValue: 13)

    @Test func captureProducesStableDetachedPresentationState() throws {
        let world = World()
        let sessionID = SimulationSessionID()
        let renderableEntity = EntityID(index: 4, generation: 0)
        let nonRenderableEntity = EntityID(index: 1, generation: 2)
        let expectedRotation = simd_quatf(
            angle: .pi / 3,
            axis: SIMD3<Float>(0, 1, 0)
        )
        let cameraPosition = SIMD3<Float>(1, 2, 8)
        world.camera = Camera(
            position: cameraPosition,
            rotation: .identity,
            projection: .orthographic(
                height: 10,
                near: 0.1,
                far: 100
            )
        )
        let renderable = CRenderable(
            meshID: Self.meshKey,
            materialID: Self.firstMaterialKey
        )
        world.renderableComponents.insert(
            renderable,
            for: renderableEntity
        )
        let renderablePositionValue = SIMD3<Float>(3, 4, 5)
        let renderablePosition = CPosition(position: renderablePositionValue)
        world.positionComponents.insert(
            renderablePosition,
            for: renderableEntity
        )
        let renderableRotation = CRotation(rotation: expectedRotation)
        world.rotationComponents.insert(
            renderableRotation,
            for: renderableEntity
        )
        let renderableScaleValue = SIMD3<Float>(repeating: 2)
        let renderableScale = CScale(scale: renderableScaleValue)
        world.scaleComponents.insert(
            renderableScale,
            for: renderableEntity
        )
        let nonRenderablePosition = CPosition(position: SIMD3<Float>(9, 9, 9))
        world.positionComponents.insert(
            nonRenderablePosition,
            for: nonRenderableEntity
        )

        let snapshotTick = SimulationTick(rawValue: 12)
        let snapshotCursor = SimulationCursor(
            sessionID: sessionID,
            tick: snapshotTick
        )
        let snapshot = world.presentationSnapshot(
            at: snapshotCursor
        )

        // Mutating authoritative state after publication must not mutate the
        // already-completed value observed by consumers.
        world.camera.position = .zero
        world.positionComponents.update(for: renderableEntity) { position in
            position.position = .zero
        }
        let didUpdateMaterial = world.renderableComponents.update(
            for: renderableEntity
        ) { renderable in
            renderable.materialID = Self.secondMaterialKey
        }
        let laterCursor = SimulationCursor(
            sessionID: sessionID,
            tick: SimulationTick(rawValue: 13)
        )
        let laterSnapshot = world.presentationSnapshot(
            at: laterCursor
        )

        #expect(didUpdateMaterial)
        #expect(snapshot.cursor.sessionID == sessionID)
        #expect(snapshot.tick == snapshotTick)
        #expect(snapshot.camera.position == cameraPosition)
        #expect(snapshot.entityPresentations.map(\.id) == [renderableEntity])

        let entity = try #require(snapshot.entityPresentations.first)
        #expect(entity.position == renderablePositionValue)
        #expect(entity.rotation?.vector == expectedRotation.vector)
        #expect(entity.scale == renderableScaleValue)
        #expect(entity.meshID == Self.meshKey)
        #expect(entity.materialID == Self.firstMaterialKey)

        // A later capture observes authoritative mutation, while the completed
        // snapshot above remains a detached point-in-time value.
        let laterEntity = try #require(laterSnapshot.entityPresentations.first)
        #expect(laterEntity.materialID == Self.secondMaterialKey)
        requireSendable(snapshot)
    }

    private func requireSendable(_ value: some Sendable) {}
}
