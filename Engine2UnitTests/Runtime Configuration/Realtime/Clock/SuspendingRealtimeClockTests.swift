import Foundation
import Testing
@testable import Engine2
@testable import Engine2RealtimeAssembly

struct SuspendingRealtimeClockTests {
    @Test func sleepAndNowShareOneMonotonicInstantDomain() async throws {
        let clock = SuspendingRealtimeClock()
        let deadline = clock.now.advanced(by: .milliseconds(1))

        try await clock.sleep(until: deadline)

        let wakeInstant = clock.now
        #expect(wakeInstant >= deadline)
    }

    @Test func sleepPropagatesTaskCancellation() async {
        let clock = SuspendingRealtimeClock()
        let deadline = clock.now.advanced(by: .seconds(60))
        let sleepTask = Task {
            try await clock.sleep(until: deadline)
        }

        sleepTask.cancel()

        do {
            try await sleepTask.value
            Issue.record("The production real-time clock ignored task cancellation.")
        } catch is CancellationError {
            // Expected cancellation is the behavior under test.
        } catch {
            Issue.record("The production real-time clock threw an unexpected error: \(error)")
        }
    }
}
