import Testing
@testable import Engine2

struct ContactDamagingTests {
    @Test func contactDamageFacadeReadsTheCurrentComponent() {
        let world = World()
        let entity = PersistentContactDamageTestEntity(
            in: world,
            from: Entity.InitialState(collisionRadius: 1, collisionResponse: .sensor, contactDamage: 2)
        )

        #expect(entity.contactDamage == HitPoints(rawValue: 2))
        #expect(world.contactConsumptionComponents[entity.id] == nil)
        #expect(world.healthComponents[entity.id] == nil)
        world.contactDamageComponents.update(for: entity.id) {
            $0 = ContactDamageComponent(amount: HitPoints(rawValue: 4))
        }

        #expect(entity.contactDamage == HitPoints(rawValue: 4))
    }
}
