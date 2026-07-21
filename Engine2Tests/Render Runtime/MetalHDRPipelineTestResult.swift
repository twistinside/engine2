import simd

/// Center samples retained from both phases of one offscreen HDR submission.
struct MetalHDRPipelineTestResult {
    /// Raw linear half-float value stored by the model scene pass.
    let sceneLinearRGBA: SIMD4<Float>

    /// Raw bytes stored by the `_srgb` presentation attachment in BGRA order.
    let presentedBGRA8: SIMD4<UInt8>
}
