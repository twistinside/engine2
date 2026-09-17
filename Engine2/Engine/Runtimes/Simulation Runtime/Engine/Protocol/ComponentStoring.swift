/// A World-owned store that inserts, updates, and removes typed component rows.
///
/// Components retains heterogeneous stores through this protocol and exposes
/// their concrete component types through its generic subscript.
protocol ComponentStoring<StoredComponent>: AnyObject {
    associatedtype StoredComponent: Component

    /// Inserts or replaces a row for the exact identity.
    /// Remove the current owner before reusing its index with another generation.
    func insert(_ component: StoredComponent, for entity: EntityID)

    /// Removes the exact identity, returning whether it owned a row.
    @discardableResult
    func remove(for entity: EntityID) -> Bool

    /// Mutates the exact identity's existing row, returning whether it existed.
    /// A missing or stale identity leaves the store unchanged and never calls body.
    @discardableResult
    func update(for entity: EntityID, _ body: (inout StoredComponent) -> Void) -> Bool
}
