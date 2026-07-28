/// Production real-time cadence clock backed by one `SuspendingClock`.
///
/// Suspending time is monotonic and excludes time while the machine sleeps, so
/// a real-time connection does not manufacture Simulation catch-up debt after
/// system suspension.
struct SuspendingRealtimeClock: PRealtimeClock {
    private let clock = SuspendingClock()

    var now: SuspendingClock.Instant {
        clock.now
    }

    func sleep(until deadline: SuspendingClock.Instant) async throws {
        try await clock.sleep(until: deadline)
    }
}
