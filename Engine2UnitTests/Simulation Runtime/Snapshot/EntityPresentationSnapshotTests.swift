import Testing
import simd
@testable import Engine2

struct EntityPresentationSnapshotTests {
    private static let defaultID = EntityID(index: 4, generation: 0)
    private static let defaultPosition = SIMD3<Float>(1, 2, 3)
    private static let defaultRotationAxis = SIMD3<Float>(0, 0, 1)
    private static let defaultRotation = simd_quatf(angle: 0, axis: defaultRotationAxis)
    private static let defaultScale = SIMD3<Float>(repeating: 2)

    @Test func equalityIncludesQuaternionVectorAndEveryOptionalTransform() {
        let rotationAxis = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(angle: .pi / 3, axis: rotationAxis)
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
        let nextGenerationID = EntityID(index: 4, generation: 1)
        let nextGeneration = makeSnapshot(id: nextGenerationID)
        let goldMetal = makeSnapshot(materialID: .goldMetal)

        #expect(baseline != nextGeneration)
        #expect(baseline != goldMetal)
    }

    private func makeSnapshot(
        id: EntityID = Self.defaultID,
        position: SIMD3<Float>? = Self.defaultPosition,
        rotation: simd_quatf? = Self.defaultRotation,
        scale: SIMD3<Float>? = Self.defaultScale,
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
