/// Backend-neutral presentation settings for one exact offscreen render.
nonisolated struct OffscreenRenderSettings: Equatable, Sendable {
    let size: RenderPixelSize
    let outputMode: RenderOutputMode
    let exposure: ManualExposure

    /// Creates the complete output policy applied to one render request.
    init(
        size: RenderPixelSize,
        outputMode: RenderOutputMode = .surface,
        exposure: ManualExposure = .validation
    ) {
        self.size = size
        self.outputMode = outputMode
        self.exposure = exposure
    }
}
