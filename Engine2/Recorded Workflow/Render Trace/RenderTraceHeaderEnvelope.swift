/// Decode-only root projection for inspecting a Render trace before its frames.
///
/// A host can reject an incompatible content identity without interpreting the
/// content-owned mesh and material vocabulary in the frame payload.
nonisolated struct RenderTraceHeaderEnvelope: Decodable, Sendable {
    let header: RenderTraceHeader
}
