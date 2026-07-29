import Foundation

/// Detached encoded image plus the exact render and encoding provenance that produced it.
///
/// This value is a derivative of an already completed offscreen render. It is
/// not authoritative presentation state, and its encoded bytes do not retain
/// GPU resources or mutable encoder storage.
public nonisolated struct RenderedImageArtifact: Equatable, Sendable {
    public let encoding: ImageArtifactEncoding
    public let encodedData: Data
    public let sourceRequestID: OffscreenRenderRequestID
    public let sourceCursor: SimulationCursor
    public let viewpoint: RenderViewpoint
    public let renderSettings: OffscreenRenderSettings

    public init(
        encoding: ImageArtifactEncoding,
        encodedData: Data,
        sourceRequestID: OffscreenRenderRequestID,
        sourceCursor: SimulationCursor,
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings
    ) {
        self.encoding = encoding
        self.encodedData = encodedData
        self.sourceRequestID = sourceRequestID
        self.sourceCursor = sourceCursor
        self.viewpoint = viewpoint
        self.renderSettings = renderSettings
    }
}
