import Engine2GPUABI

extension HDRPresentationParameters {
    /// Packs semantic exposure into the shared raw presentation record.
    init(exposure: ManualExposure) {
        self.init()
        self.exposurePadding = SIMD4<Float>(exposure.multiplier, 0, 0, 0)
    }
}
