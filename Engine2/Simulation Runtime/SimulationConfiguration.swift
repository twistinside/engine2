import simd

/// Immutable camera policy required to construct the foundational Simulation schedule.
///
/// The value keeps camera-orbit constraints consistent across every system in one
/// Simulation Runtime. Its initializer validates the complete policy;
/// Game Content or the Runtime Assembly must deliberately select a named production
/// value instead of letting individual systems choose local defaults.
nonisolated struct SimulationConfiguration: Equatable, Sendable {
    /// Complete camera policy selected by Basic Game Content.
    static let basicGame = Self(
        cameraOrbitTarget: .zero,
        cameraOrbitAxis: SIMD3<Float>(0, 1, 0),
        minimumCameraOrbitRadius: 2,
        maximumCameraOrbitRadius: 30
    )

    /// Camera policy for the mining slice's large planar world.
    static let miningGame = Self(
        cameraOrbitTarget: .zero,
        cameraOrbitAxis: SIMD3<Float>(0, 0, 1),
        minimumCameraOrbitRadius: 250,
        maximumCameraOrbitRadius: 2_500
    )

    let cameraOrbitAxis: SIMD3<Float>
    let cameraOrbitTarget: SIMD3<Float>
    let minimumCameraOrbitRadius: Float
    let maximumCameraOrbitRadius: Float

    init(
        cameraOrbitTarget: SIMD3<Float>,
        cameraOrbitAxis: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        minimumCameraOrbitRadius: Float,
        maximumCameraOrbitRadius: Float
    ) {
        precondition(
            cameraOrbitTarget.isFinite,
            "Camera orbit target must be finite."
        )
        let orbitAxisLength = simd_length(cameraOrbitAxis)
        precondition(
            cameraOrbitAxis.isFinite && orbitAxisLength.isFinite && orbitAxisLength > 0,
            "Camera orbit axis must be finite and nonzero."
        )
        precondition(
            minimumCameraOrbitRadius.isFinite && minimumCameraOrbitRadius > 0,
            "Camera orbit minimum radius must be finite and positive."
        )
        precondition(
            maximumCameraOrbitRadius.isFinite && maximumCameraOrbitRadius >= minimumCameraOrbitRadius,
            "Camera orbit maximum radius must be finite and no smaller than its minimum."
        )

        self.cameraOrbitTarget = cameraOrbitTarget
        self.cameraOrbitAxis = cameraOrbitAxis / orbitAxisLength
        self.minimumCameraOrbitRadius = minimumCameraOrbitRadius
        self.maximumCameraOrbitRadius = maximumCameraOrbitRadius
    }
}
