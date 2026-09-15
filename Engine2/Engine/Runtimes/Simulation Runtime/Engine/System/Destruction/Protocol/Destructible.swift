/// A reference whose owner can defer removal until its current work finishes.
///
/// Conformance requires no Entity inheritance or component storage. Entity supplies this
/// capability for every subclass and retains its rows until the Engine's final collection.
protocol Destructible: AnyObject {
    /// Requests removal and reports whether it is pending, including an earlier accepted request.
    /// Repeated requests are harmless; an unavailable or already removed object returns false.
    @discardableResult
    func markForRemoval() -> Bool
}
