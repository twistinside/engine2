/// Records compact practice-mode input snapshots after mapping and camera use.
struct SInputHistory: PSystem {
    mutating func update(world: inout World, deltaTime: Float) {
        world.input.recordHistoryFrame()
    }
}
