import SwiftUI

/// Common construction and root-view boundary for one Runtime topology.
///
/// The App supplies Game Content, then the assembly constructs and retains its
/// complete Runtime graph. SwiftUI may copy the assembly value, but every copy
/// retains the same reference-owned graph. The assembly's body owns any
/// topology-specific presentation lifecycle.
public protocol PRuntimeAssembly: View {
    /// Constructs the complete topology from caller-selected Game Content.
    ///
    /// Fallible assemblies throw before publishing a usable graph. The App must
    /// select a launch-failure policy when it chooses one of those assembly types.
    init(gameContent: any PGameContent) throws
}
