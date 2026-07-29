import Testing
@testable import Engine2
@testable import Engine2AgentSessionAssembly

struct AgentSessionRequestSequenceProgressTests {
    @Test func nonzeroInitialSequenceClassifiesExactAndGapCandidatesWithoutHighWater() {
        let previous = AgentSessionRequestSequence(rawValue: 40)
        let initial = AgentSessionRequestSequence(rawValue: 41)
        let gap = AgentSessionRequestSequence(rawValue: 42)
        let progress = AgentSessionRequestSequenceProgress(initialSequence: initial)

        #expect(progress.classification(of: initial) == .expected)
        #expect(progress.classification(of: previous) == .unexpected(expected: initial))
        #expect(progress.classification(of: gap) == .unexpected(expected: initial))
        #expect(!progress.isExhausted)
    }

    @Test func acceptingExpectedSequenceAdvancesHighWaterAndNextExpectation() {
        let older = AgentSessionRequestSequence(rawValue: 0)
        let initial = AgentSessionRequestSequence(rawValue: 41)
        let next = AgentSessionRequestSequence(rawValue: 42)
        let following = AgentSessionRequestSequence(rawValue: 43)
        var progress = AgentSessionRequestSequenceProgress(initialSequence: initial)

        progress.accept(initial)

        #expect(progress.classification(of: older) == .atOrBelowAcceptedHighWater)
        #expect(progress.classification(of: initial) == .atOrBelowAcceptedHighWater)
        #expect(progress.classification(of: next) == .expected)
        #expect(progress.classification(of: following) == .unexpected(expected: next))

        progress.accept(next)

        #expect(progress.classification(of: next) == .atOrBelowAcceptedHighWater)
        #expect(progress.classification(of: following) == .expected)
        #expect(!progress.isExhausted)
    }

    @Test func acceptingMaximumSequencePreservesHighWaterInExhaustedState() {
        let first = AgentSessionRequestSequence.first
        let maximum = AgentSessionRequestSequence(rawValue: .max)
        var progress = AgentSessionRequestSequenceProgress(initialSequence: maximum)

        #expect(progress.classification(of: maximum) == .expected)

        progress.accept(maximum)

        #expect(progress.isExhausted)
        #expect(progress.classification(of: maximum) == .atOrBelowAcceptedHighWater)
        #expect(progress.classification(of: first) == .atOrBelowAcceptedHighWater)
    }
}
