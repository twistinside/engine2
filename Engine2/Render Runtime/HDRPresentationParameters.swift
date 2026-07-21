/// GPU input for the tone-mapped HDR presentation fragment.
///
/// A full four-float lane gives the Swift/Metal boundary an unambiguous
/// 16-byte layout while reserving no accidental semantic meaning for padding.
struct HDRPresentationParameters {
    var exposurePadding: SIMD4<Float>

    init(exposure: ManualExposure) {
        self.exposurePadding = SIMD4<Float>(exposure.multiplier, 0, 0, 0)
    }
}
