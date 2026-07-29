/// Read-only latest-value boundary published by an Input Runtime.
public protocol PInputSnapshotSource: AnyObject {
    var latestInputSnapshot: InputSnapshot { get }
}
