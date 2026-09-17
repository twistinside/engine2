/// Retains one value-semantic store at a stable location inside Components.
///
/// The container erases this reference's type internally and restores it for
/// typed access. Copying the contained store still creates an independent value.
final class ComponentStorage<C: Component> {
    var value: ComponentStore<C>

    init() {
        value = ComponentStore<C>()
    }
}
