import simd

nonisolated extension simd_quatf {
    /// Rotation identity that leaves vectors unchanged.
    static let identity = simd_quatf(real: 1, imag: .zero)
}
