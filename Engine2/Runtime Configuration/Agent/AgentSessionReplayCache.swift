/// Bounded FIFO storage for exact live-process agent response replay.
///
/// The cache owns entry-count bounds and aggregate raw/encoded image-byte
/// accounting over the exact footprint cached by each entry. A response larger
/// than the complete byte budget is deliberately not retained; accepted request
/// high-water remains outside this value so the coordinator can still distinguish
/// that unretained identity from fresh work.
nonisolated struct AgentSessionReplayCache: Sendable {
    private let maximumResultCount: Int
    private let maximumImageBytes: Int

    private var entries: [AgentSessionRequestID: AgentSessionReplayEntry] = [:]
    private var retentionOrder: [AgentSessionRequestID] = []
    private var retainedImageBytes = 0

    /// Creates storage with explicit positive count and nonnegative byte bounds.
    init(maximumResultCount: Int, maximumImageBytes: Int) {
        precondition(maximumResultCount > 0, "An agent replay cache must retain space for at least one result.")
        precondition(maximumImageBytes >= 0, "Agent replay cache image-byte budget cannot be negative.")

        self.maximumResultCount = maximumResultCount
        self.maximumImageBytes = maximumImageBytes
    }

    /// Returns the exact paired values retained for one request identity.
    func entry(for requestID: AgentSessionRequestID) -> AgentSessionReplayEntry? {
        entries[requestID]
    }

    /// Retains an entry after evicting the oldest values required by policy.
    mutating func retain(_ entry: AgentSessionReplayEntry) {
        precondition(entries[entry.requestID] == nil, "An accepted agent request identity can enter replay storage only once.")

        let imageBytes = entry.retainedImageByteCount
        guard imageBytes <= maximumImageBytes else {
            return
        }

        while retentionOrder.count >= maximumResultCount
            || retainedImageBytes > maximumImageBytes - imageBytes {
            let oldestID = retentionOrder.removeFirst()
            guard let evictedEntry = entries.removeValue(forKey: oldestID) else {
                preconditionFailure("Agent replay retention order must reference a retained entry.")
            }
            retainedImageBytes -= evictedEntry.retainedImageByteCount
        }

        entries[entry.requestID] = entry
        retentionOrder.append(entry.requestID)
        retainedImageBytes += imageBytes
    }

}
