/// Backend-neutral presentation settings for one exact offscreen render.
public nonisolated struct OffscreenRenderSettings: Equatable, Sendable {
    public let size: RenderPixelSize
    public let outputMode: RenderOutputMode
    public let exposure: ManualExposure

    public init(
        size: RenderPixelSize,
        outputMode: RenderOutputMode,
        exposure: ManualExposure
    ) {
        self.size = size
        self.outputMode = outputMode
        self.exposure = exposure
    }
}
