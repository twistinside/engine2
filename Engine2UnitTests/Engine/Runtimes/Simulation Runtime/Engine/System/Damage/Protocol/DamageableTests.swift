import Testing
@testable import Engine2

struct DamageableTests {
    @Test func damageableHealthDoesNotRequireCollisionOrMovement() {
        let world = World()
        let entity = NonphysicalDamageableTestEntity(in: world, from: Entity.InitialState(health: 3))

        #expect(entity.health == HitPoints(rawValue: 3))
        #expect(world.positionComponents[entity.id] == nil)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.collisionBodyComponents[entity.id] == nil)
        #expect(world.contactDamageComponents[entity.id] == nil)
        #expect(world.contactConsumptionComponents[entity.id] == nil)

        world.healthComponents.update(for: entity.id) { $0.applyDamage(HitPoints(rawValue: 2)) }

        #expect(entity.health == HitPoints(rawValue: 1))
        #expect(entity.lifecycleState == .active)
    }
}
