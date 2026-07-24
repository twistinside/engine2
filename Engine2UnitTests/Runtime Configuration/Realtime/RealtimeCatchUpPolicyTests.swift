import Testing
@testable import Engine2

struct RealtimeCatchUpPolicyTests {
    @Test func interactiveDefaultBoundsWorkAndDiscardsOverflow() {
        #expect(
            RealtimeCatchUpPolicy.interactive == RealtimeCatchUpPolicy(
                maximumStepsPerWake: SimulationStepCount(rawValue: 4),
                backlogTreatment: .discardOverflow
            )
        )
        requireSendable(RealtimeCatchUpPolicy.interactive)
    }

    private func requireSendable(_ value: some Sendable) {}
}
