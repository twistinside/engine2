import Foundation
import Testing
@testable import Engine2

struct SimulationSessionIDTests {
    @Test func defaultInitializationCreatesOpaqueUniqueIdentities() {
        let first = SimulationSessionID()
        let second = SimulationSessionID()

        #expect(first != second)
    }

    @Test func rawIdentitySupportsDeterministicRestorationAndCoding() throws {
        let optionalRawValue = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        let rawValue = try #require(optionalRawValue)
        let sessionID = SimulationSessionID(rawValue: rawValue)

        let data = try JSONEncoder().encode(sessionID)
        let decoded = try JSONDecoder().decode(
            SimulationSessionID.self,
            from: data
        )

        #expect(sessionID.rawValue == rawValue)
        #expect(decoded == sessionID)
        requireRawRepresentable(sessionID)
    }

    @Test func rawIdentityPreservesZeroAndMaximumUUIDBitPatterns() throws {
        let optionalZero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")
        let optionalMaximum = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
        let zero = try #require(optionalZero)
        let maximum = try #require(optionalMaximum)
        let zeroSessionID = SimulationSessionID(rawValue: zero)
        let maximumSessionID = SimulationSessionID(rawValue: maximum)

        #expect(zeroSessionID.rawValue == zero)
        #expect(maximumSessionID.rawValue == maximum)
    }

    private func requireRawRepresentable(_ value: some RawRepresentable) {}
}
