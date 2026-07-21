/// Row population for one component store at an inventory boundary.
struct ComponentStoreInventory: Codable, Equatable, Sendable {
    let storeID: ComponentStoreDiagnosticsID
    let rowCount: Int
}
