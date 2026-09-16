import Foundation
import Testing
@testable import Engine2

struct DestructibleComponentTests {
    @Test func pendingRemovalRoundTripsWithoutReactivatingTheEntity() throws {
        var component = DestructibleComponent()
        component.state = .pendingRemoval
        let encoded = try JSONEncoder().encode(component)

        let decoded = try JSONDecoder().decode(DestructibleComponent.self, from: encoded)

        #expect(decoded.state == .pendingRemoval)
    }
}
