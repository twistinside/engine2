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
    }
}
