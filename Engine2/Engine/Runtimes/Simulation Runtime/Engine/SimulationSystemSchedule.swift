/// Ordered Game Content behavior inserted into the Simulation Runtime's fixed schedule.
///
/// The Engine owns its camera, integration, and cleanup foundation. Game Content
/// can contribute systems only at these explicit boundaries, which preserves one
/// complete deterministic tick while allowing composed gameplay.
struct SimulationSystemSchedule {
    static let empty = SimulationSystemSchedule()

    let inputConsumption: [any System]
    let worldPreparation: [any System]
    let forceContribution: [any System]
    let postMovement: [any System]
    let prePresentation: [any System]

    init(
        inputConsumption: [any System] = [],
        worldPreparation: [any System] = [],
        forceContribution: [any System] = [],
        postMovement: [any System] = [],
        prePresentation: [any System] = []
    ) {
        self.inputConsumption = inputConsumption
        self.worldPreparation = worldPreparation
        self.forceContribution = forceContribution
        self.postMovement = postMovement
        self.prePresentation = prePresentation
    }
}
