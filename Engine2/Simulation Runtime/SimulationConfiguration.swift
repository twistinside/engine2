import simd

/// Immutable behavior policy required to construct the foundational Simulation schedule.
///
/// The value keeps camera-control sensitivities and orbit constraints consistent across
/// every system in one Simulation Runtime. Its initializer validates the complete policy;
/// Game Content or the App composition root must deliberately select a named production
/// value instead of letting individual systems choose local defaults.
nonisolated struct SimulationConfiguration: Equatable, Sendable {
    let pointerOrbitSensitivity: Float
    let scrollZoomSensitivity: Float
    let cameraOrbitTarget: SIMD3<Float>
    let minimumCameraOrbitRadius: Float
    let maximumCameraOrbitRadius: Float

    init(
        pointerOrbitSensitivity: Float,
        scrollZoomSensitivity: Float,
        cameraOrbitTarget: SIMD3<Float>,
        minimumCameraOrbitRadius: Float,
        maximumCameraOrbitRadius: Float
    ) {
        precondition(pointerOrbitSensitivity.isFinite, "Pointer orbit sensitivity must be finite.")
        precondition(scrollZoomSensitivity.isFinite, "Scroll zoom sensitivity must be finite.")
        precondition(
            cameraOrbitTarget.x.isFinite && cameraOrbitTarget.y.isFinite && cameraOrbitTarget.z.isFinite,
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

        self.pointerOrbitSensitivity = pointerOrbitSensitivity
        self.scrollZoomSensitivity = scrollZoomSensitivity
        self.cameraOrbitTarget = cameraOrbitTarget
        self.minimumCameraOrbitRadius = minimumCameraOrbitRadius
        self.maximumCameraOrbitRadius = maximumCameraOrbitRadius
    }
}
