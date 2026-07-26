import Testing
@testable import Engine2

struct SimulationCursorTests {
    @Test func sessionQualificationDistinguishesEqualTickValues() {
        let tick = SimulationTick(rawValue: 42)
        let firstSessionID = SimulationSessionID()
        let first = SimulationCursor(
            sessionID: firstSessionID,
            tick: tick
        )
        let secondSessionID = SimulationSessionID()
        let second = SimulationCursor(
            sessionID: secondSessionID,
            tick: tick
        )

        #expect(first != second)
        #expect(first.tick == second.tick)
    }

    @Test func advancedPreservesSessionAndAdvancesOnlyTheTick() {
        let sessionID = SimulationSessionID()
        let initialTick = SimulationTick(rawValue: 41)
        let cursor = SimulationCursor(
            sessionID: sessionID,
            tick: initialTick
        )
        let expectedTick = SimulationTick(rawValue: 42)
        let expected = SimulationCursor(
            sessionID: sessionID,
            tick: expectedTick
        )

        #expect(cursor.advanced() == expected)
    }
}
