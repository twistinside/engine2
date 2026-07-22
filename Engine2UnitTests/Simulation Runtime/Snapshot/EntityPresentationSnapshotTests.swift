import Testing
import simd
@testable import Engine2

struct EntityPresentationSnapshotTests {
    @Test func equalityIncludesQuaternionVectorAndEveryOptionalTransform() {
        let rotation = simd_quatf(angle: .pi / 3, axis: SIMD3<Float>(0, 1, 0))
        let first = makeSnapshot(rotation: rotation)
        let second = makeSnapshot(rotation: simd_quatf(vector: rotation.vector))

        #expect(first == second)
        #expect(first != makeSnapshot(position: nil, rotation: rotation))
        #expect(first != makeSnapshot(rotation: nil))
        #expect(first != makeSnapshot(rotation: rotation, scale: nil))
    }

    @Test func equalityIncludesGenerationalIdentityAndAuthoredMaterial() {
        let baseline = makeSnapshot()

        #expect(baseline != makeSnapshot(id: EntityID(index: 4, generation: 1)))
        #expect(baseline != makeSnapshot(materialID: .goldMetal))
    }

    private func makeSnapshot(
        id: EntityID = EntityID(index: 4, generation: 0),
        position: SIMD3<Float>? = SIMD3<Float>(1, 2, 3),
        rotation: simd_quatf? = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1)),
        scale: SIMD3<Float>? = SIMD3<Float>(repeating: 2),
        materialID: MaterialID = .warmDielectric
    ) -> EntityPresentationSnapshot {
        EntityPresentationSnapshot(
            id: id,
            position: position,
            rotation: rotation,
            scale: scale,
            meshID: .ball,
            materialID: materialID
        )
    }
}
