import Engine2
import Engine2AssemblySupport
/// Monotonic time and absolute suspension used by one real-time cadence connection.
///
/// One conforming value supplies both sampling and sleeping so elapsed-time
/// accounting and polling deadlines always share the same instant domain.
protocol PRealtimeClock: Sendable {
    /// Current monotonic instant.
    var now: SuspendingClock.Instant { get }

    /// Suspends until an absolute monotonic deadline.
    func sleep(until deadline: SuspendingClock.Instant) async throws
}
