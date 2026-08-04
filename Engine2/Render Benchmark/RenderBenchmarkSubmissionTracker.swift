import Foundation

/// Thread-safe completion ledger and terminal GPU-error latch for one phase.
///
/// Warm-up and measured phases use separate ledgers so warm-up timings cannot
/// enter the result. `drain()` waits for every registered feedback callback,
/// then either returns all successful measured samples or rethrows the first
/// GPU-side failure.
nonisolated final class RenderBenchmarkSubmissionTracker: @unchecked Sendable {
    private let condition = NSCondition()
    private var inFlightSubmissionCount = 0
    private var samples: [RenderBenchmarkSample] = []
    private var storedError: RenderBenchmarkError?

    /// Registers one imminent queue commit unless feedback already failed.
    func registerSubmission() throws(RenderBenchmarkError) {
        condition.lock()
        defer { condition.unlock() }

        if let storedError {
            throw storedError
        }

        inFlightSubmissionCount += 1
    }

    /// Records one terminal feedback result and wakes a waiting drain.
    func complete(
        sample: RenderBenchmarkSample?,
        error: RenderBenchmarkError?
    ) {
        condition.lock()
        precondition(
            inFlightSubmissionCount > 0,
            "Benchmark feedback cannot complete an unregistered submission."
        )

        if let sample {
            samples.append(sample)
        }
        if storedError == nil {
            storedError = error
        }
        inFlightSubmissionCount -= 1
        if inFlightSubmissionCount == 0 {
            condition.broadcast()
        }
        condition.unlock()
    }

    /// Waits for all registered submissions and returns samples in input order.
    func drain() throws(RenderBenchmarkError) -> [RenderBenchmarkSample] {
        condition.lock()
        while inFlightSubmissionCount > 0 {
            condition.wait()
        }
        let completedSamples = samples.sorted {
            if $0.iteration == $1.iteration {
                return $0.sequence < $1.sequence
            }
            return $0.iteration < $1.iteration
        }
        let error = storedError
        condition.unlock()

        if let error {
            throw error
        }
        return completedSamples
    }
}
