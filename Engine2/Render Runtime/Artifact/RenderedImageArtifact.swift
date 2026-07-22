import Foundation

/// Detached encoded image plus the exact render and encoding provenance that produced it.
///
/// This value is a derivative of an already completed offscreen render. It is
/// not authoritative presentation state, and its encoded bytes do not retain
/// GPU resources or mutable encoder storage.
nonisolated struct RenderedImageArtifact: Equatable, Sendable {
    let format: ImageArtifactFormat
    let encodedData: Data
    let sourceRequestID: OffscreenRenderRequestID
    let sourceCursor: SimulationCursor
    let viewpoint: RenderViewpoint
    let renderSettings: OffscreenRenderSettings
    let jpegSettings: JPEGEncodingSettings

    /// Creates an artifact while preserving all attribution from its source render.
    init(
        format: ImageArtifactFormat,
        encodedData: Data,
        sourceRequestID: OffscreenRenderRequestID,
        sourceCursor: SimulationCursor,
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        jpegSettings: JPEGEncodingSettings
    ) {
        self.format = format
        self.encodedData = encodedData
        self.sourceRequestID = sourceRequestID
        self.sourceCursor = sourceCursor
        self.viewpoint = viewpoint
        self.renderSettings = renderSettings
        self.jpegSettings = jpegSettings
    }
}
