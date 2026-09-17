/// Authoritative per-axis scale for one entity.
///
/// Capability-driven registration defaults this value to unit scale. Render
/// extraction can carry it across a snapshot boundary without exposing the
/// component store itself.
struct ScaleComponent: Component {
    let scale: SIMD3<Float>
}

extension ScaleComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            state.scale == nil || entity is Scalable,
            "Initial state.scale requires Scalable conformance"
        )
        guard entity is Scalable else {
            return nil
        }

        self.init(scale: state.scale ?? SIMD3<Float>(repeating: 1))
    }
}
