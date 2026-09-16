import Foundation
import Testing
@testable import Engine2

struct EntityLifecycleComponentTests {
    @Test func pendingRemovalRoundTripsWithoutReactivatingTheEntity() throws {
        var component = EntityLifecycleComponent()
        component.state = .pendingRemoval
        let encoded = try JSONEncoder().encode(component)

        let decoded = try JSONDecoder().decode(EntityLifecycleComponent.self, from: encoded)

        #expect(decoded.state == .pendingRemoval)
    }
}
