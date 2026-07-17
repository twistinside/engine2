import Testing
@testable import Engine2

struct SimulationTickTests {
    @Test func advancedReturnsNextStronglyTypedIdentity() {
        let tick = SimulationTick(rawValue: 41)

        #expect(tick.advanced() == SimulationTick(rawValue: 42))
        #expect(SimulationTick.zero < tick)
    }
}
