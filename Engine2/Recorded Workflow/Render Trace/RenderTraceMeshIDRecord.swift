/// Stable schema-v1 mesh vocabulary recorded independently of domain coding.
nonisolated enum RenderTraceMeshIDRecord: String, Codable, Sendable {
    case ball

    /// Reconstructs the Game Content mesh identity.
    var value: MeshID {
        switch self {
        case .ball:
            .ball
        }
    }

    init(_ meshID: MeshID) {
        switch meshID {
        case .ball:
            self = .ball
        }
    }
}
