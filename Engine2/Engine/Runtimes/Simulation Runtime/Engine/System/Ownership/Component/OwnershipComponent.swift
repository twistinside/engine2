/// Current owner identity, mutable through its store and retained when the owner is destroyed.
struct OwnershipComponent: Component {
    var ownerEntityID: EntityID
}
