import simd

/// Immutable behavior policy required to construct the foundational Simulation schedule.
///
/// The value keeps Simulation time scale, camera-control policy, and orbit constraints
/// consistent across every system in one Simulation Runtime. Its initializer validates
/// the complete policy; Game Content or the Runtime Assembly must deliberately select a
/// named production value instead of letting individual systems choose local defaults.
nonisolated struct SimulationConfiguration: Equatable, Sendable {
    /// Complete Simulation behavior policy selected by Basic Game Content.
    static let basicGame = Self(
        simulationTimeScale: .realTime,
        pointerOrbitSensitivity: 0.01,
        scrollZoomSensitivity: 0.04,
        cameraOrbitTarget: .zero,
        minimumCameraOrbitRadius: 2,
        maximumCameraOrbitRadius: 30
    )

    /// Complete Simulation behavior policy selected by Solar System Game Content.
    static let solarSystem = Self(
        simulationTimeScale: .solarSystemSmokeTest,
        pointerOrbitSensitivity: 0.01,
        scrollZoomSensitivity: 4.0e10,
        cameraOrbitTarget: .zero,
        minimumCameraOrbitRadius: 2.0e12,
        maximumCameraOrbitRadius: 3.0e13
    )

    /// Authored ratio of authoritative world time to the nominal Simulation base interval.
    let simulationTimeScale: SimulationTimeScale

    let pointerOrbitSensitivity: Float
    let scrollZoomSensitivity: Float
    let cameraOrbitTarget: SIMD3<Float>
    let minimumCameraOrbitRadius: Float
    let maximumCameraOrbitRadius: Float

    init(
        simulationTimeScale: SimulationTimeScale,
        pointerOrbitSensitivity: Float,
        scrollZoomSensitivity: Float,
        cameraOrbitTarget: SIMD3<Float>,
        minimumCameraOrbitRadius: Float,
        maximumCameraOrbitRadius: Float
    ) {
        precondition(pointerOrbitSensitivity.isFinite, "Pointer orbit sensitivity must be finite.")
        precondition(scrollZoomSensitivity.isFinite, "Scroll zoom sensitivity must be finite.")
        precondition(
            cameraOrbitTarget.isFinite,
            "Camera orbit target must be finite."
        )
        precondition(
            minimumCameraOrbitRadius.isFinite && minimumCameraOrbitRadius > 0,
            "Camera orbit minimum radius must be finite and positive."
        )
        precondition(
            maximumCameraOrbitRadius.isFinite && maximumCameraOrbitRadius >= minimumCameraOrbitRadius,
            "Camera orbit maximum radius must be finite and no smaller than its minimum."
        )

        self.simulationTimeScale = simulationTimeScale
        self.pointerOrbitSensitivity = pointerOrbitSensitivity
        self.scrollZoomSensitivity = scrollZoomSensitivity
        self.cameraOrbitTarget = cameraOrbitTarget
        self.minimumCameraOrbitRadius = minimumCameraOrbitRadius
        self.maximumCameraOrbitRadius = maximumCameraOrbitRadius
    }
}
