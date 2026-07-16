//
//  MeshIDTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

import Foundation
import Testing
@testable import Engine2

struct MeshIDTests {
    @Test func codableRoundTripPreservesBackendNeutralIdentity() throws {
        let original = MeshID(rawValue: "test.mesh")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MeshID.self, from: data)

        #expect(decoded == original)
        #expect(decoded.rawValue == "test.mesh")
    }

    @Test func hashingDistinguishesDifferentMeshIdentities() {
        let identities: Set<MeshID> = [
            MeshID(rawValue: "first"),
            MeshID(rawValue: "second"),
            MeshID(rawValue: "first")
        ]

        #expect(identities.count == 2)
    }
}
