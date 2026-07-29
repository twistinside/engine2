import Engine2
import Engine2AssemblySupport
/// Shares visibility policy and transition identity across copies of one assembly.
///
/// A new ``RealtimeAssembly`` constructs one state owner. SwiftUI may copy the
/// assembly value, but every copy retains this same owner. Root visibility and
/// scene activity jointly decide whether real-time work may run, while transition
/// identity prevents older asynchronous work from overriding a newer decision.
/// Scene activity remains conservative until the view reports its initial phase.
final class RealtimeAssemblyLifecycleState {
    private var generation: UInt64 = 0

    private var isRootVisible = false

    private var isSceneActive = false

    /// Whether both root-view visibility and topology-local scene policy permit work.
    var permitsRunning: Bool {
        isRootVisible && isSceneActive
    }

    /// Records whether SwiftUI currently presents the assembly's root view.
    func setRootVisible(_ isVisible: Bool) {
        isRootVisible = isVisible
    }

    /// Records whether this real-time topology may run in the current scene phase.
    func setSceneActive(_ isActive: Bool) {
        isSceneActive = isActive
    }

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
