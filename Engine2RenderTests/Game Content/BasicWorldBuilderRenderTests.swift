import Testing
import simd
@testable import Engine2
@testable import BasicGameContent

struct BasicWorldBuilderRenderTests {
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

    private static let expectedProjectedScale = SIMD3<Float>(repeating: 0.5)

    @Test func materialSphereSceneUsesOrdinarySnapshotAndRenderFramePath() {
        let world = BasicWorldBuilder().buildWorld()
        let tick = SimulationTick(rawValue: 41)
        let cursor = SimulationCursor(
            sessionID: SimulationSessionID(),
            tick: tick
        )
        let snapshot = world.presentationSnapshot(at: cursor)
        let frame = RenderFrame(projecting: snapshot)
        let expectedMeshKeys = Array(
            repeating: MeshID.ball.assetKey,
            count: Self.expectedEntityIDs.count
        )
        let expectedMaterialKeys = Self.expectedMaterialIDs.map(\.assetKey)

        #expect(snapshot.tick == tick)
        #expect(snapshot.cursor == cursor)
        expectReferenceCamera(snapshot.camera)
        #expect(snapshot.entityPresentations.map(\.id) == Self.expectedEntityIDs)
        #expect(
            snapshot.entityPresentations.compactMap(\.position) ==
                Self.expectedPositions
        )
        #expect(
            snapshot.entityPresentations.map(\.materialID) ==
                expectedMaterialKeys
        )
        #expect(
            snapshot.entityPresentations.map(\.meshID) ==
                expectedMeshKeys
        )
        #expect(snapshot.entityPresentations.allSatisfy { $0.scale == nil })

        #expect(frame.sourceCursor == cursor)
        #expect(frame.sourceTick == tick)
        expectReferenceCamera(frame.camera)
        #expect(frame.instances.map(\.transform.position) == Self.expectedPositions)
        #expect(frame.instances.map(\.materialID) == expectedMaterialKeys)
        #expect(
            frame.instances.map(\.meshID) ==
                expectedMeshKeys
        )
        #expect(
            frame.instances.map(\.transform.scale) ==
                Array(
                    repeating: Self.expectedProjectedScale,
                    count: Self.expectedEntityIDs.count
                )
        )
        for instance in frame.instances {
            #expect(
                instance.transform.rotation.vector ==
                    simd_quatf.identity.vector
            )
        }

        // ECS remains authoritative and mutable, while both completed boundary
        // values above stay detached from later world changes.
        let firstEntity = Self.expectedEntityIDs[0]
        let didMove = world.positionComponents.update(for: firstEntity) {
            $0.position = SIMD3<Float>(99, 99, 99)
        }
        let didChangeMaterial = world.renderableComponents.update(
            for: firstEntity
        ) {
            $0.materialID = MaterialID.goldMetalRough.assetKey
        }

        #expect(didMove)
        #expect(didChangeMaterial)
        #expect(snapshot.entityPresentations[0].position == Self.expectedPositions[0])
        #expect(
            snapshot.entityPresentations[0].materialID ==
                expectedMaterialKeys[0]
        )
        #expect(frame.instances[0].transform.position == Self.expectedPositions[0])
        #expect(frame.instances[0].materialID == expectedMaterialKeys[0])
    }

    private func expectReferenceCamera(_ camera: Camera) {
        #expect(camera.position == SIMD3<Float>(0, 0, 8))
        #expect(camera.rotation.vector == simd_quatf.identity.vector)

        switch camera.projection {
        case let .perspective(verticalFieldOfView, near, far):
            #expect(verticalFieldOfView == Float.pi / 3)
            #expect(near == 0.1)
            #expect(far == 100)

        case .orthographic:
            Issue.record("The material validation camera must remain perspective.")
        }
    }
}
