/// Exhaustive Render Runtime identity for compiled Metal render pipelines.
nonisolated enum MetalRenderPipelineID: String, Codable, CaseIterable, Hashable, Sendable {
    case modelPBR
    case modelNormalDiagnostic
    case hdrToneMappedPresentation
    case linearPresentation
}
