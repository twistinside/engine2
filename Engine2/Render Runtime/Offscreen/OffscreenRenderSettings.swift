/// Backend-neutral presentation settings for one exact offscreen render.
nonisolated struct OffscreenRenderSettings: Equatable, Sendable {
    let size: RenderPixelSize
    let outputMode: RenderOutputMode
    let exposure: ManualExposure
}
