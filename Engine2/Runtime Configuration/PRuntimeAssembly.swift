import SwiftUI

/// Common App-hosting boundary and root view for one complete Runtime topology.
///
/// Each conforming assembly selects and constructs its production graph through
/// a zero-argument initializer and supplies its UI through the `body` requirement
/// inherited from SwiftUI's `View` protocol. Assemblies are value-type handles
/// because SwiftUI requires custom views to use value semantics. Copies retain
/// the same reference-owned Runtime graph; only initialization constructs a new
/// graph. Runtime capabilities remain on the concrete assembly so this protocol
/// does not become an optional service bag or a second authority surface.
protocol PRuntimeAssembly: View {
    /// Constructs the assembly's required production topology without arguments.
    ///
    /// Assemblies that require fallible resources throw before publishing a usable
    /// graph. The App must select a launch-failure policy when it chooses one of
    /// those assembly types. A root view may still demand-create an explicitly
    /// optional adapter.
    init() throws
}
