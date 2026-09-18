/// Current owner identity, mutable through its store and retained when the owner is destroyed.
struct OwnershipComponent: Component {
    var ownerEntityID: EntityID
}

extension OwnershipComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(
            (state.ownerEntityID != nil) == (entity is Ownable),
            "InitialState.ownerEntityID must be present exactly when the entity conforms to Ownable."
        )
        guard let ownerEntityID = state.ownerEntityID else {
            return nil
        }
        self.init(ownerEntityID: ownerEntityID)
    }
}
