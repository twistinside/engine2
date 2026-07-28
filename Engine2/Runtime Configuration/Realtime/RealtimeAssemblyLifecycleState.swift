/// Shares lifecycle transition identity across value copies of one real-time assembly.
///
/// A new ``RealtimeAssembly`` constructs one state owner. SwiftUI may copy the
/// assembly value, but every copy retains this same owner so an older asynchronous
/// stop or rebuild cannot override a newer lifecycle request.
final class RealtimeAssemblyLifecycleState {
    private var generation: UInt64 = 0

    /// Advances lifecycle identity and returns the selected generation.
    @discardableResult
    func beginTransition() -> UInt64 {
        precondition(generation < .max, "Real-time assembly lifecycle generation exhausted.")
        generation += 1
        return generation
    }

    /// Reports whether no newer lifecycle transition superseded `generation`.
    func isCurrent(_ generation: UInt64) -> Bool {
        self.generation == generation
    }
}
