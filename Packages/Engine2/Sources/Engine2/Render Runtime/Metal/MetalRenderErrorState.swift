import Foundation

/// Thread-safe terminal-error channel for the Metal render pathway.
///
/// Frame preparation occurs on the main actor, while a queue's feedback closure
/// may report a GPU failure elsewhere. This narrow state object accepts both
/// sources and preserves the underlying error for renderer diagnostics without
/// making either path reach into UI or runtime lifecycle. A successful queue
/// completion does not erase an earlier failure.
nonisolated final class MetalRenderErrorState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedError: (any Error)?

    var latestError: (any Error)? {
        lock.lock()
        defer { lock.unlock() }
        return storedError
    }

    func record(_ error: (any Error)?) {
        guard let error else {
            return
        }

        lock.lock()
        storedError = error
        lock.unlock()
    }

    /// Performs one submission action only while no terminal error is recorded.
    ///
    /// The same lock linearizes queue commit against asynchronous feedback. If
    /// feedback records first, the action is skipped; if this action enters
    /// first, that submission is ordered before the later recorded failure.
    @discardableResult
    func performIfHealthy(_ action: () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard storedError == nil else {
            return false
        }

        action()
        return true
    }
}
