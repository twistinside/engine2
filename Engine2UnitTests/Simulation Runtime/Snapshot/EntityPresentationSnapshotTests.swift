import Testing
import simd
@testable import Engine2
@testable import BasicGameContent

struct EntityPresentationSnapshotTests {
    @Test func equalityIncludesQuaternionVectorAndEveryOptionalTransform() {
        let rotation = simd_quatf(angle: .pi / 3, axis: SIMD3<Float>(0, 1, 0))
        let first = makeSnapshot(rotation: rotation)
        let equivalentRotation = simd_quatf(vector: rotation.vector)
        let second = makeSnapshot(rotation: equivalentRotation)
        let missingPosition = makeSnapshot(position: nil, rotation: rotation)
        let missingRotation = makeSnapshot(rotation: nil)
        let missingScale = makeSnapshot(rotation: rotation, scale: nil)

        #expect(first == second)
        #expect(first != missingPosition)
        #expect(first != missingRotation)
        #expect(first != missingScale)
    }

    @Test func equalityIncludesGenerationalIdentityAndAuthoredMaterial() {
        let baseline = makeSnapshot()
        let nextGeneration = makeSnapshot(
            id: EntityID(index: 4, generation: 1)
        )
        let goldMetal = makeSnapshot(materialID: .goldMetal)

        #expect(baseline != nextGeneration)
        #expect(baseline != goldMetal)
    }

    private func makeSnapshot(
        id: EntityID = EntityID(index: 4, generation: 0),
        position: SIMD3<Float>? = SIMD3<Float>(1, 2, 3),
        rotation: simd_quatf? = simd_quatf.identity,
        scale: SIMD3<Float>? = SIMD3<Float>(repeating: 2),
        materialID: MaterialID = .warmDielectric
    ) -> EntityPresentationSnapshot {
        EntityPresentationSnapshot(
            id: id,
            position: position,
            rotation: rotation,
            scale: scale,
            meshID: MeshID.ball.assetKey,
            materialID: materialID.assetKey
        )
    }
}
