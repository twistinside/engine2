import Foundation
import Testing
@testable import Engine2

struct SimulationSessionIDTests {
    @Test func defaultInitializationCreatesOpaqueUniqueIdentities() {
        #expect(SimulationSessionID() != SimulationSessionID())
    }

    @Test func rawIdentitySupportsDeterministicRestorationAndCoding() throws {
        let rawValue = try #require(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        )
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
        let zero = try #require(
            UUID(uuidString: "00000000-0000-0000-0000-000000000000")
        )
        let maximum = try #require(
            UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
        )

        #expect(SimulationSessionID(rawValue: zero).rawValue == zero)
        #expect(SimulationSessionID(rawValue: maximum).rawValue == maximum)
    }

    private func requireRawRepresentable(_ value: some RawRepresentable) {}
}
