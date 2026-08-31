/// Read-only UI-facing access to the currently selected live entity facade.
///
/// The source exposes no World mutation or Simulation advancement authority.
/// Capability protocols project each value from authoritative ECS stores when
/// the inspector reads the returned facade.
protocol PSelectedEntitySource: AnyObject {
    var selectedEntity: Entity? { get }
}
