import Testing
@testable import Engine2

struct SimulationStepCountTests {
    @Test func preservesPositiveRequestedCount() {
        let count = SimulationStepCount(rawValue: 37)

        #expect(count.rawValue == 37)
        #expect(SimulationStepCount.one.rawValue == 1)
        requireSendable(count)
    }

    private func requireSendable(_ value: some Sendable) {}
}
