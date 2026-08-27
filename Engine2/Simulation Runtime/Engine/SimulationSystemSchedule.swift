/// Ordered Game Content behavior inserted into the Simulation Runtime's fixed schedule.
///
/// The Engine owns the foundational input, camera, integration, history, and cleanup
/// systems. Game Content can contribute systems only at these explicit boundaries,
/// which preserves one complete deterministic tick while allowing composed gameplay.
struct SimulationSystemSchedule {
    static let empty = SimulationSystemSchedule()

    let inputConsumption: [any PSystem]
    let worldPreparation: [any PSystem]
    let forceContribution: [any PSystem]
    let postMovement: [any PSystem]
    let prePresentation: [any PSystem]

    init(
        inputConsumption: [any PSystem] = [],
        worldPreparation: [any PSystem] = [],
        forceContribution: [any PSystem] = [],
        postMovement: [any PSystem] = [],
        prePresentation: [any PSystem] = []
    ) {
        self.inputConsumption = inputConsumption
        self.worldPreparation = worldPreparation
        self.forceContribution = forceContribution
        self.postMovement = postMovement
        self.prePresentation = prePresentation
    }
}
