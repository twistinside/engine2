/// A World-owned store that removes rows by their complete entity identity.
///
/// Components retains heterogeneous stores through this protocol and exposes
/// their concrete component types through its generic subscript.
protocol ComponentStoring: AnyObject {
    /// Removes the exact identity, returning whether it owned a row.
    @discardableResult
    func remove(for entity: EntityID) -> Bool
}
