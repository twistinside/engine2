extension SimulationConfiguration {
    /// Complete Simulation behavior policy authored for Basic Game Content.
    static let basicGame = Self(
        pointerOrbitSensitivity: 0.01,
        scrollZoomSensitivity: 0.04,
        cameraOrbitTarget: .zero,
        minimumCameraOrbitRadius: 2,
        maximumCameraOrbitRadius: 30
    )
}
