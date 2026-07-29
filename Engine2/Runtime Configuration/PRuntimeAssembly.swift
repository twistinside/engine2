import SwiftUI

/// Common construction, visibility, and root-view boundary for one Runtime topology.
///
/// The App supplies Game Content, then the assembly constructs and retains its
/// complete Runtime graph. SwiftUI may copy the assembly value, but every copy
/// retains the same reference-owned graph. Visibility callbacks govern reversible
/// work associated with presenting the root view. Topology-specific capabilities
/// and terminal lifecycle remain on the concrete assembly.
protocol PRuntimeAssembly: View {
    /// Constructs the complete topology from caller-selected Game Content.
    ///
    /// Fallible assemblies throw before publishing a usable graph. The App must
    /// select a launch-failure policy when it chooses one of those assembly types.
    init(gameContent: any PGameContent) throws

    /// Starts or resumes reversible work associated with a visible root view.
    ///
    /// Calls may repeat as SwiftUI rebuilds or presents the view.
    func onAppear()

    /// Begins stopping reversible work when the root view is no longer visible.
    ///
    /// Disappearance does not end a terminal session. A topology that owns final
    /// shutdown or drain semantics exposes that operation through its concrete API.
    /// An implementation that drains asynchronously owns that task and protects
    /// newer appearance state from stale completion.
    func onDisappear()
}

extension PRuntimeAssembly {
    /// Performs no work for a topology without visibility-scoped activity.
    func onAppear() {}

    /// Performs no work for a topology without visibility-scoped activity.
    func onDisappear() {}
}
