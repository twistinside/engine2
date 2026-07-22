import Testing
import simd
@testable import Engine2

struct SimulationPresentationSnapshotTests {
    @Test func captureProducesStableDetachedPresentationState() throws {
        let world = World()
        let sessionID = SimulationSessionID()
        let renderableEntity = EntityID(index: 4, generation: 0)
        let nonRenderableEntity = EntityID(index: 1, generation: 2)
        let expectedRotation = simd_quatf(
            angle: .pi / 3,
            axis: SIMD3<Float>(0, 1, 0)
        )
        world.camera = Camera(
            position: SIMD3<Float>(1, 2, 8),
            orthographicHeight: 10
        )
        world.renderableComponents.insert(
            CRenderable(
                meshID: .ball,
                materialID: .warmDielectric
            ),
            for: renderableEntity
        )
        world.positionComponents.insert(
            CPosition(position: SIMD3<Float>(3, 4, 5)),
            for: renderableEntity
        )
        world.rotationComponents.insert(
            CRotation(rotation: expectedRotation),
            for: renderableEntity
        )
        world.scaleComponents.insert(
            CScale(scale: SIMD3<Float>(repeating: 2)),
            for: renderableEntity
        )
        world.positionComponents.insert(
            CPosition(position: SIMD3<Float>(9, 9, 9)),
            for: nonRenderableEntity
        )

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: SimulationCursor(
                sessionID: sessionID,
                tick: SimulationTick(rawValue: 12)
            )
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
            renderable.materialID = .goldMetal
        }
        let laterSnapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: SimulationCursor(
                sessionID: sessionID,
                tick: SimulationTick(rawValue: 13)
            )
        )

        #expect(didUpdateMaterial)
        #expect(snapshot.cursor.sessionID == sessionID)
        #expect(snapshot.tick == SimulationTick(rawValue: 12))
        #expect(snapshot.camera.position == SIMD3<Float>(1, 2, 8))
        #expect(snapshot.entityPresentations.map(\.id) == [renderableEntity])

        let entity = try #require(snapshot.entityPresentations.first)
        #expect(entity.position == SIMD3<Float>(3, 4, 5))
        #expect(entity.rotation?.vector == expectedRotation.vector)
        #expect(entity.scale == SIMD3<Float>(repeating: 2))
        #expect(entity.meshID == .ball)
        #expect(entity.materialID == .warmDielectric)

        // A later capture observes authoritative mutation, while the completed
        // snapshot above remains a detached point-in-time value.
        let laterEntity = try #require(laterSnapshot.entityPresentations.first)
        #expect(laterEntity.materialID == .goldMetal)
        requireSendable(snapshot)
    }

    private func requireSendable(_ value: some Sendable) {}
}
