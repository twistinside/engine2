/// Exhaustive Render Runtime identity for compiled Metal render pipelines.
nonisolated enum MetalRenderPipelineID: Hashable, Sendable {
    case modelPBR
    case modelNormalDiagnostic
    case hdrToneMappedPresentation
    case linearPresentation
}
