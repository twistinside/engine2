import Foundation

/// Selects whether the explorer presents formation facts or orbital dynamics for one generated system.
enum StarSystemExplorerWorkspace: String, CaseIterable, Identifiable {
    case generation
    case dynamics

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .generation: "Generation"
        case .dynamics: "Dynamics"
        }
    }

    var systemImage: String {
        switch self {
        case .generation: "sparkles"
        case .dynamics: "point.3.connected.trianglepath.dotted"
        }
    }
}
