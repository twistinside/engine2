import Foundation
import Testing
@testable import Engine2

struct RealtimeStepAccumulatorTests {
    private let fixedTimeStep = Duration.milliseconds(100)

    @Test func substepElapsedTimeRemainsDebtWithoutProducingARequest() {
        var accumulator = makeAccumulator()

        let stepCount = accumulator.consumeSteps(adding: .milliseconds(40))

        #expect(stepCount == nil)
        #expect(accumulator.elapsedRemainder == .milliseconds(40))
    }

    @Test func completeStepsAreConsumedWhileFractionalTimeRemains() {
        var accumulator = makeAccumulator()

        let stepCount = accumulator.consumeSteps(adding: .milliseconds(250))

        #expect(stepCount == SimulationStepCount(rawValue: 2))
        #expect(accumulator.elapsedRemainder == .milliseconds(50))
    }

    @Test func preservePolicyDrainsBoundedBacklogAcrossCalls() {
        var accumulator = makeAccumulator(
            maximumStepsPerWake: 3,
            backlogTreatment: .preserve
        )

        let firstBatch = accumulator.consumeSteps(adding: .milliseconds(550))
        let secondBatch = accumulator.consumeSteps(adding: .zero)

        #expect(firstBatch == SimulationStepCount(rawValue: 3))
        #expect(secondBatch == SimulationStepCount(rawValue: 2))
        #expect(accumulator.elapsedRemainder == .milliseconds(50))
    }

    @Test func discardPolicyDropsAWholeStepOverflowAndItsFraction() {
        var accumulator = makeAccumulator(
            maximumStepsPerWake: 3,
            backlogTreatment: .discardOverflow
        )

        let stepCount = accumulator.consumeSteps(adding: .milliseconds(550))

        #expect(stepCount == SimulationStepCount(rawValue: 3))
        #expect(accumulator.elapsedRemainder == .zero)
    }

    @Test func discardPolicyKeepsFractionWhenNoWholeStepOverflows() {
        var accumulator = makeAccumulator(
            maximumStepsPerWake: 3,
            backlogTreatment: .discardOverflow
        )

        let stepCount = accumulator.consumeSteps(adding: .milliseconds(350))

        #expect(stepCount == SimulationStepCount(rawValue: 3))
        #expect(accumulator.elapsedRemainder == .milliseconds(50))
    }

    @Test func resetDropsUnrequestedElapsedDebt() {
        var accumulator = makeAccumulator()
        _ = accumulator.consumeSteps(adding: .milliseconds(40))

        accumulator.reset()

        #expect(accumulator.elapsedRemainder == .zero)
    }

    private func makeAccumulator(
        maximumStepsPerWake: UInt32 = 4,
        backlogTreatment: RealtimeBacklogTreatment = .discardOverflow
    ) -> RealtimeStepAccumulator {
        RealtimeStepAccumulator(
            fixedTimeStep: fixedTimeStep,
            catchUpPolicy: RealtimeCatchUpPolicy(
                maximumStepsPerWake: SimulationStepCount(rawValue: maximumStepsPerWake),
                backlogTreatment: backlogTreatment
            )
        )
    }
}
