/// Records compact practice-mode input snapshots after mapping and camera use.
struct SInputHistory: PSystem {
    let diagnosticsID: SimulationSystemID? = .inputHistory

    mutating func update(world: inout World, deltaTime: Float) {
        world.input.recordHistoryFrame()
    }
}
