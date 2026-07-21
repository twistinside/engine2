/// Preserved Render construction failure reported before the original throw.
struct RenderResourceFailureDiagnostics: Codable, Equatable, Sendable {
    let stage: RenderResourceConstructionStage

    /// Error types are an open vocabulary because Metal and Model I/O may
    /// supply framework-defined conformers outside Engine2's closed enums.
    let errorType: String
}
