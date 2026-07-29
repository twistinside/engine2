import Testing
@testable import Engine2
@testable import Engine2RealtimeAssembly

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
