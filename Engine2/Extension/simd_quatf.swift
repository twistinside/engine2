import simd

nonisolated extension simd_quatf {
    /// Rotation identity that leaves vectors unchanged.
    static var identity: Self {
        Self(real: 1, imag: .zero)
    }
}
