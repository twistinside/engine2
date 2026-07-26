import Testing
@testable import Engine2

struct SimulationStepCountTests {
    @Test func preservesNormalOneAndMaximumRequestedCounts() {
        let normal = SimulationStepCount(rawValue: 37)
        let maximum = SimulationStepCount(rawValue: .max)

        #expect(normal.rawValue == 37)
        #expect(SimulationStepCount.one.rawValue == 1)
        #expect(maximum.rawValue == .max)
        requireRawRepresentable(normal)
        requireSendable(normal)
    }

    @Test func validatingInitializerRejectsZeroWithoutTrapping() {
        let zero = SimulationStepCount(validating: 0)
        let one = SimulationStepCount(validating: 1)
        let maximum = SimulationStepCount(validating: .max)

        #expect(zero == nil)
        #expect(one == .one)
        #expect(maximum?.rawValue == UInt32.max)
    }

    private func requireRawRepresentable(_ value: some RawRepresentable) {}
    private func requireSendable(_ value: some Sendable) {}
}
