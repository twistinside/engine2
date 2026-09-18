/// Selects source removal after its first eligible contact, independently of outgoing damage.
struct ContactConsumptionComponent: Component {}

extension ContactConsumptionComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        guard entity is ContactConsumable else {
            return nil
        }
        self.init()
    }
}
