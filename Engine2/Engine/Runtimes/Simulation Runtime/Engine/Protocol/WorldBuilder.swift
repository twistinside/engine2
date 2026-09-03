
/// Creates a fully bootstrapped world for a new simulation session or load operation.
protocol WorldBuilder {
    func buildWorld() -> World
}
