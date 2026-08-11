import Foundation
import Testing
@testable import Engine2

/// Test support for controlled persistence corruption and immutable system replacement.
nonisolated struct GeneratedStarSystemFixture {
    let system: GeneratedStarSystem

    func canonicalFingerprint() throws -> UInt64 {
        let fnvOffsetBasis: UInt64 = 14_695_981_039_346_656_037
        let fnvPrime: UInt64 = 1_099_511_628_211
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let encoded = try encoder.encode(system)
        return encoded.reduce(fnvOffsetBasis) { partial, byte in
            (partial ^ UInt64(byte)) &* fnvPrime
        }
    }

    func decoded(
        after mutation: (inout [String: Any]) throws -> Void
    ) throws -> GeneratedStarSystem {
        let encoded = try JSONEncoder().encode(system)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        try mutation(&object)
        let mutated = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(GeneratedStarSystem.self, from: mutated)
    }

    func replacingLedger(_ ledger: StarSystemFormationLedger) -> GeneratedStarSystem {
        GeneratedStarSystem(
            seed: system.seed,
            modelVersion: system.modelVersion,
            policy: system.policy,
            star: system.star,
            protoplanetaryDisk: system.protoplanetaryDisk,
            formationLedger: ledger,
            planets: system.planets
        )
    }

    func replacingPlanets(_ planets: [GeneratedPlanet]) -> GeneratedStarSystem {
        GeneratedStarSystem(
            seed: system.seed,
            modelVersion: system.modelVersion,
            policy: system.policy,
            star: system.star,
            protoplanetaryDisk: system.protoplanetaryDisk,
            formationLedger: system.formationLedger,
            planets: planets
        )
    }
}
