/// Renderer-owned manual exposure expressed as a direct scene-linear multiplier.
///
/// The first HDR presentation path deliberately avoids ambiguous camera-stop
/// terminology: the shader multiplies scene color by this finite, nonnegative
/// value before tone mapping. A future UI may convert stops with `exp2`, but the
/// GPU contract remains an explicit multiplier.
nonisolated struct ManualExposure: Equatable, Sendable {
    /// Stable validation exposure used by the first visible PBR pathway.
    static let validation = ManualExposure(multiplier: 1)

    let multiplier: Float

    init(multiplier: Float) {
        precondition(
            multiplier.isFinite && multiplier >= 0,
            "Manual exposure must be finite and nonnegative."
        )
        self.multiplier = multiplier
    }
}
