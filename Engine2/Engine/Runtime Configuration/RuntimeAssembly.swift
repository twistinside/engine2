import SwiftUI

/// Common construction and root-view boundary for one Runtime topology.
///
/// The App supplies Game Content, then the assembly constructs and retains its
/// complete Runtime graph. SwiftUI may copy the assembly value, but every copy
/// retains the same reference-owned graph. The assembly's body owns any
/// topology-specific presentation lifecycle.
protocol RuntimeAssembly: View {
    /// Constructs the complete topology from caller-selected Game Content.
    init(using content: any GameContent)
}
