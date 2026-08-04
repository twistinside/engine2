/// Stable schema-v1 Render output-mode vocabulary.
nonisolated enum RenderTraceOutputModeRecord: String, Codable, Sendable {
    case surface
    case viewSpaceNormals

    /// Reconstructs the Render-owned visualization choice.
    var value: RenderOutputMode {
        switch self {
        case .surface:
            .surface
        case .viewSpaceNormals:
            .viewSpaceNormals
        }
    }

    init(_ outputMode: RenderOutputMode) {
        switch outputMode {
        case .surface:
            self = .surface
        case .viewSpaceNormals:
            self = .viewSpaceNormals
        }
    }
}
