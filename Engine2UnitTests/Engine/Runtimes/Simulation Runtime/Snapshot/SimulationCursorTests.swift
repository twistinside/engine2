import Testing
@testable import Engine2

struct SimulationCursorTests {
    @Test func sessionQualificationDistinguishesEqualTickValues() {
        let tick = SimulationTick(rawValue: 42)
        let first = SimulationCursor(
            sessionID: SimulationSessionID(),
            tick: tick
        )
        let second = SimulationCursor(
            sessionID: SimulationSessionID(),
            tick: tick
        )

        #expect(first != second)
        #expect(first.tick == second.tick)
    }

    @Test func advancedPreservesSessionAndAdvancesOnlyTheTick() {
        let sessionID = SimulationSessionID()
        let cursor = SimulationCursor(
            sessionID: sessionID,
            tick: SimulationTick(rawValue: 41)
        )

        #expect(
            cursor.advanced() == SimulationCursor(
                sessionID: sessionID,
                tick: SimulationTick(rawValue: 42)
            )
        )
    }
}
