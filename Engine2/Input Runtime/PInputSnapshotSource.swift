/// Read-only latest-value boundary published by an Input Runtime.
@MainActor
protocol PInputSnapshotSource: AnyObject {
    var latestInputSnapshot: InputSnapshot { get }
}
