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
}
