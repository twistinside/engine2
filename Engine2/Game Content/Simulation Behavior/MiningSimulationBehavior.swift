/// Composes the mining slice inside the Engine's controlled schedule stages.
struct MiningSimulationBehavior: SimulationBehavior {
    func makeSystemSchedule() -> SimulationSystemSchedule {
        SimulationSystemSchedule(
            inputConsumption: [
                PlanarSelectionSystem(),
                SelectedEntityControlSystem(),
                OrbitCircularizationSystem(),
            ],
            worldPreparation: [
                MissileLaunchSystem(),
                PreviousPositionCaptureSystem(),
                OrbitalRailSystem(),
            ],
            forceContribution: [
                GravitySystem(),
                OrbitCircularizationAutopilotSystem(completionTolerance: 0.5),
                FlightControlSystem(targetSpeed: 90, responseTime: 2),
            ],
            postMovement: [
                CollisionSystem(),
                ContactEffectSystem(),
                LifetimeSystem(),
                CollisionResponseSystem(),
                MiningInteractionSystem(),
                CameraFollowSystem(),
            ]
        )
    }
}
