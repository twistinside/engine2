import Foundation
import Testing
@testable import Engine2

struct HealthComponentTests {
    @Test func exhaustedHealthRoundTripsWithoutRestoringIt() throws {
        var component = HealthComponent(health: HitPoints(rawValue: 1))
        component.applyDamage(HitPoints(rawValue: 1))
        let encoded = try JSONEncoder().encode(component)

        let decoded = try JSONDecoder().decode(HealthComponent.self, from: encoded)

        #expect(decoded.health == .zero)
    }

    @Test func damageExceedingRemainingHealthClampsAtZero() {
        var component = HealthComponent(health: HitPoints(rawValue: 1))

        component.applyDamage(HitPoints(rawValue: 0.25))
        #expect(component.health == HitPoints(rawValue: 0.75))
        component.applyDamage(HitPoints(rawValue: .greatestFiniteMagnitude))
        #expect(component.health == .zero)
        component.applyDamage(HitPoints(rawValue: 1))
        #expect(component.health == .zero)
    }
}
