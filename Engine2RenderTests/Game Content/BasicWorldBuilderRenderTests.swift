import Testing
import simd
@testable import Engine2

@MainActor
struct BasicWorldBuilderRenderTests {
    @Test func materialSphereSceneUsesOrdinarySnapshotAndRenderFramePath() {
        let world = BasicWorldBuilder().buildWorld()
        let tick = SimulationTick(rawValue: 41)
        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: tick
        )
        let frame = RenderFrame.project(from: snapshot)

        #expect(snapshot.tick == tick)
        expectReferenceCamera(snapshot.camera)
        #expect(snapshot.entityPresentations.map(\.id) == Self.expectedEntityIDs)
        #expect(
            snapshot.entityPresentations.compactMap(\.position) ==
                Self.expectedPositions
        )
        #expect(
            snapshot.entityPresentations.map(\.materialID) ==
                Self.expectedMaterialIDs
        )
        #expect(
            snapshot.entityPresentations.map(\.meshID) ==
                Array(repeating: MeshID.ball, count: Self.expectedEntityIDs.count)
        )
        #expect(snapshot.entityPresentations.allSatisfy { $0.scale == nil })

        #expect(frame.sourceTick == tick)
        expectReferenceCamera(frame.camera)
        #expect(frame.instances.map(\.transform.position) == Self.expectedPositions)
        #expect(frame.instances.map(\.materialID) == Self.expectedMaterialIDs)
        #expect(
            frame.instances.map(\.meshID) ==
                Array(repeating: MeshID.ball, count: Self.expectedEntityIDs.count)
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
                    Self.identityRotation.vector
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
            $0.materialID = .goldMetalRough
        }

        #expect(didMove)
        #expect(didChangeMaterial)
        #expect(snapshot.entityPresentations[0].position == Self.expectedPositions[0])
        #expect(
            snapshot.entityPresentations[0].materialID ==
                Self.expectedMaterialIDs[0]
        )
        #expect(frame.instances[0].transform.position == Self.expectedPositions[0])
        #expect(frame.instances[0].materialID == Self.expectedMaterialIDs[0])
    }

    private func expectReferenceCamera(_ camera: Camera) {
        #expect(camera.position == SIMD3<Float>(0, 0, 8))
        #expect(camera.rotation.vector == Self.identityRotation.vector)

        switch camera.projection {
        case let .perspective(verticalFieldOfView, near, far):
            #expect(verticalFieldOfView == Float.pi / 3)
            #expect(near == 0.1)
            #expect(far == 100)

        case .orthographic:
            Issue.record("The material validation camera must remain perspective.")
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

    private static let expectedProjectedScale = SIMD3<Float>(repeating: 0.5)

    private static let identityRotation = simd_quatf(
        angle: 0,
        axis: SIMD3<Float>(0, 0, 1)
    )
}
