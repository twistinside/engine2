/// Marker row for an entity whose motion accumulator receives gravity.
struct GravityReceiverComponent: Component {}

extension GravityReceiverComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        guard entity is GravityAffected else {
            return nil
        }
        self.init()
    }
}
