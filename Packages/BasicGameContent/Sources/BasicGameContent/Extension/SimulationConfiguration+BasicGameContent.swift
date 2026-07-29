import Engine2

public extension SimulationConfiguration {
    /// Complete Simulation behavior policy selected by Basic Game Content.
    static let basicGame = Self(
        pointerOrbitSensitivity: 0.01,
        scrollZoomSensitivity: 0.04,
        cameraOrbitTarget: .zero,
        minimumCameraOrbitRadius: 2,
        maximumCameraOrbitRadius: 30
    )
}
