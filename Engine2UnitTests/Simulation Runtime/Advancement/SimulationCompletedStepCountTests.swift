import Testing
@testable import Engine2

struct SimulationCompletedStepCountTests {
    @Test func permitsZeroAndFullUnsignedRange() {
        let maximum = SimulationCompletedStepCount(rawValue: .max)

        #expect(SimulationCompletedStepCount.zero.rawValue == 0)
        #expect(maximum.rawValue == .max)
        requireSendable(maximum)
    }

    private func requireSendable(_ value: some Sendable) {}
}
