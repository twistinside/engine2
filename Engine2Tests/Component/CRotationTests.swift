//
//  CRotationTests.swift
//  Engine2Tests
//
//  Created by Codex on 3/15/26.
//

import Foundation
import Testing
import simd
@testable import Engine2

struct CRotationTests {
    @Test func codableRoundTripsQuaternion() throws {
        let original = CRotation(
            rotation: simd_quatf(
                angle: .pi / 3,
                axis: simd_normalize(SIMD3<Float>(1, 2, 3))
            )
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CRotation.self, from: data)

        #expect(decoded == original)
        #expect(decoded.rotation.vector == original.rotation.vector)
    }

    @Test func equalityUsesQuaternionVector() async throws {
        let rotation = simd_quatf(
            angle: .pi / 4,
            axis: simd_normalize(SIMD3<Float>(0, 1, 1))
        )
        let identical = CRotation(rotation: rotation)
        let sameRotationOppositeSign = CRotation(rotation: simd_quatf(vector: -rotation.vector))

        #expect(CRotation(rotation: rotation) == identical)
        #expect(CRotation(rotation: rotation) != sameRotationOppositeSign)
    }
}
