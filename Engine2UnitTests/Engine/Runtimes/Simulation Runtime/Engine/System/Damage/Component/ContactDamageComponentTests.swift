import Foundation
import Testing
@testable import Engine2

struct ContactDamageComponentTests {
    @Test func positiveDamageRoundTripsThroughJSON() throws {
        let component = ContactDamageComponent(amount: HitPoints(rawValue: 0.25))
        let encoded = try JSONEncoder().encode(component)

        let decoded = try JSONDecoder().decode(ContactDamageComponent.self, from: encoded)

        #expect(decoded.amount == component.amount)
    }

    @Test(arguments: [0, -1])
    func decodingRejectsNonpositiveDamage(rawValue: Int) {
        let data = Data("{\"amount\":{\"rawValue\":\(rawValue)}}".utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ContactDamageComponent.self, from: data)
        }
    }
}
