/// Records compact practice-mode input snapshots before transient cleanup.
struct SInputHistory: PSystem {
    mutating func update(world: inout World, deltaTime: Float) {
        world.input.recordHistoryFrame()
    }
}
