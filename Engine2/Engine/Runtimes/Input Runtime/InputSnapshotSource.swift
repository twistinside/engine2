/// Read-only latest-value boundary published by an Input Runtime.
protocol InputSnapshotSource: AnyObject {
    var latestInputSnapshot: InputSnapshot { get }
}
