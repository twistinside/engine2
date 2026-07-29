
/// Creates a fully bootstrapped world for a new simulation session or load operation.
public protocol PWorldBuilder {
    func buildWorld() -> World
}
