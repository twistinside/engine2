/// App-owned control capability kept separate from runtime measurement sites.
@MainActor
protocol PDiagnosticsController: PDiagnosticsSnapshotSource {
    func setCollectionEnabled(_ isEnabled: Bool)
    func reset()
}
