import Foundation
import Testing
import simd
@testable import Engine2

struct CRotationTests {
    @Test func identityUsesNeutralQuaternion() {
        let identityAxis = SIMD3<Float>(0, 0, 1)
        let expectedRotation = simd_quatf(angle: 0, axis: identityAxis)

        #expect(CRotation.identity.rotation.vector == expectedRotation.vector)
    }

    @Test func codableRoundTripsQuaternion() throws {
        let axis = SIMD3<Float>(1, 2, 3)
        let normalizedAxis = simd_normalize(axis)
        let rotation = simd_quatf(angle: .pi / 3, axis: normalizedAxis)
        let original = CRotation(rotation: rotation)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CRotation.self, from: data)

        #expect(decoded == original)
        #expect(decoded.rotation.vector == original.rotation.vector)
    }

    @Test func equalityUsesQuaternionVector() async throws {
        let axis = SIMD3<Float>(0, 1, 1)
        let normalizedAxis = simd_normalize(axis)
        let rotation = simd_quatf(
            angle: .pi / 4,
            axis: normalizedAxis
        )
        let identical = CRotation(rotation: rotation)
        let oppositeSignRotation = simd_quatf(vector: -rotation.vector)
        let sameRotationOppositeSign = CRotation(rotation: oppositeSignRotation)
        let equivalent = CRotation(rotation: rotation)

        #expect(equivalent == identical)
        #expect(equivalent != sameRotationOppositeSign)
    }
}
