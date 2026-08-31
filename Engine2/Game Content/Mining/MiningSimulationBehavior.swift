/// Composes the mining slice inside the Engine's controlled schedule stages.
struct MiningSimulationBehavior: PSimulationBehavior {
    func makeSystemSchedule() -> SimulationSystemSchedule {
        SimulationSystemSchedule(
            inputConsumption: [
                SPlanarSelection(),
                SSelectedEntityControl(),
                SOrbitCircularization(),
            ],
            worldPreparation: [
                SPreviousPositionCapture(),
                SOrbitalRail(),
            ],
            forceContribution: [
                SGravity(),
                SOrbitCircularizationAutopilot(completionTolerance: 0.5),
                SFlightControl(targetSpeed: 90, responseTime: 2),
            ],
            postMovement: [
                SSweptCollision(),
                SMiningInteraction(),
                SCameraFollow(),
            ]
        )
    }
}
