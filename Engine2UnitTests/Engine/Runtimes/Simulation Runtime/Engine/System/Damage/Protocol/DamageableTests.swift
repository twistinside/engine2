import Testing
@testable import Engine2

struct DamageableTests {
    @Test func damageableHealthDoesNotRequireCollisionOrMovement() {
        let world = World()
        let entity = NonphysicalDamageableTestEntity(in: world, from: Entity.InitialState(health: 3))

        #expect(entity.health == HitPoints(rawValue: 3))
        #expect(world.components[PositionComponent.self][entity.id] == nil)
        #expect(world.components[MotionComponent.self][entity.id] == nil)
        #expect(world.components[CollisionBodyComponent.self][entity.id] == nil)
        #expect(world.components[ContactDamageComponent.self][entity.id] == nil)
        #expect(world.components[ContactConsumptionComponent.self][entity.id] == nil)

        world.components[HealthComponent.self].update(for: entity.id) { $0.applyDamage(HitPoints(rawValue: 2)) }

        #expect(entity.health == HitPoints(rawValue: 1))
        #expect(entity.lifecycleState == .active)
    }
}
