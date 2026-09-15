@testable import Engine2

/// Implements destruction requests independently of Entity and World.
final class StandaloneDestructibleTestObject: Destructible {
    private(set) var removalRequested = false

    func markForRemoval() -> Bool {
        removalRequested = true
        return true
    }
}
