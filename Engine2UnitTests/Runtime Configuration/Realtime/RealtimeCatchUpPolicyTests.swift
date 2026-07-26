import Testing
@testable import Engine2

struct RealtimeCatchUpPolicyTests {
    @Test func interactiveDefaultBoundsWorkAndDiscardsOverflow() {
        let maximumStepsPerWake = SimulationStepCount(rawValue: 4)
        let expected = RealtimeCatchUpPolicy(
            maximumStepsPerWake: maximumStepsPerWake,
            backlogTreatment: .discardOverflow
        )
        #expect(RealtimeCatchUpPolicy.interactive == expected)
        requireSendable(RealtimeCatchUpPolicy.interactive)
    }

    private func requireSendable(_ value: some Sendable) {}
}
