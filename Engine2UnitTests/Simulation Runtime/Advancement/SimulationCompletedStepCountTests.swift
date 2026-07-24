import Testing
@testable import Engine2

struct SimulationCompletedStepCountTests {
    @Test func permitsZeroOneAndFullUnsignedRange() {
        let one = SimulationCompletedStepCount(rawValue: 1)
        let maximum = SimulationCompletedStepCount(rawValue: .max)

        #expect(SimulationCompletedStepCount.zero.rawValue == 0)
        #expect(one.rawValue == 1)
        #expect(maximum.rawValue == .max)
        requireRawRepresentable(one)
        requireSendable(maximum)
    }

    private func requireRawRepresentable(_ value: some RawRepresentable) {}
    private func requireSendable(_ value: some Sendable) {}
}
