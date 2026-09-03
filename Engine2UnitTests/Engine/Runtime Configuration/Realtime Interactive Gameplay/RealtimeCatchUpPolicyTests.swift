import Testing
@testable import Engine2

struct RealtimeCatchUpPolicyTests {
    @Test func interactiveDefaultBoundsWorkAndDiscardsOverflow() {
        let expected = RealtimeCatchUpPolicy(
            maximumStepsPerWake: SimulationStepCount(rawValue: 4),
            backlogTreatment: .discardOverflow
        )
        #expect(RealtimeCatchUpPolicy.interactive == expected)
        requireSendable(RealtimeCatchUpPolicy.interactive)
    }

    private func requireSendable(_ value: some Sendable) {}
}
