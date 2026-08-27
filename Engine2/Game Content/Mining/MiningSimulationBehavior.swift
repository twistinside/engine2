/// Composes the mining slice inside the Engine's controlled schedule stages.
struct MiningSimulationBehavior: PSimulationBehavior {
    func makeSystemSchedule() -> SimulationSystemSchedule {
        SimulationSystemSchedule(
            inputConsumption: [
                SPlanarSelection(),
                SSelectedEntityControl(),
            ],
            worldPreparation: [
                SPreviousPositionCapture(),
                SOrbitalRail(),
            ],
            forceContribution: [
                SGravity(),
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
