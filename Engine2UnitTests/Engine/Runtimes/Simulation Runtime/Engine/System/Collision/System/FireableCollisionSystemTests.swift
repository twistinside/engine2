import Testing
@testable import Engine2

struct FireableCollisionSystemTests {
    @Test func detectionRecordsContactWithoutChangingParticipants() throws {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)
        let registeredIDs = scene.world.registeredEntities.map(\.id)
        let collisionIDs = scene.world.collisionBodyComponents.entities

        var detector = FireableCollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.fireableCollisions.count == 1)
        let contact = try #require(scene.world.fireableCollisions.first)
        #expect(contact.entityID == missile.id)
        #expect(contact.targetEntityID == target.id)
        #expect(abs(contact.tickFraction - 0.48) < 1e-12)
        #expect(scene.world.pendingRemovalComponents.entities.isEmpty)
        #expect(scene.world.registeredEntities.map(\.id) == registeredIDs)
        #expect(scene.world.collisionBodyComponents.entities == collisionIDs)
        #expect(scene.world.positionComponents[missile.id]?.position == SIMD3<Double>(110, 0, 0))
        #expect(scene.world.previousPositionComponents[missile.id]?.position == SIMD3<Double>(10, 0, 0))
        #expect(scene.world.motionComponents[missile.id]?.velocity == SIMD3<Double>(100, 0, 0))
        #expect(scene.world.lifetimeComponents[missile.id]?.remainingLifetime == 5)
        #expect(scene.world.renderableComponents[missile.id] != nil)
        #expect(scene.world.renderableComponents[target.id] != nil)
    }

    @Test(arguments: [0, -1, Double.infinity, Double.nan])
    func invalidDurationClearsContactsFromThePreviousUpdate(deltaTime: Double) {
        var scene = MissileTestScene(velocity: .zero)
        _ = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        _ = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)
        var detector = FireableCollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.fireableCollisions.count == 1)

        detector.update(world: &scene.world, deltaTime: deltaTime)

        #expect(scene.world.fireableCollisions.isEmpty)
        #expect(scene.world.pendingRemovalComponents.entities.isEmpty)
    }

    @Test func updateWithNoFiredBodiesClearsPreviousContacts() {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)
        var detector = FireableCollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.fireableCollisions.count == 1)
        scene.world.destroy(missile.id)

        detector.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.fireableCollisions.isEmpty)
        #expect(scene.world.entity(for: target.id) === target)
        #expect(scene.world.pendingRemovalComponents.entities.isEmpty)
    }

    @Test(arguments: [false, true])
    func pendingParticipantDoesNotProduceAContact(markFiredBody: Bool) {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)
        let pendingEntity: Entity = markFiredBody ? missile : target
        #expect(pendingEntity.markForRemoval())

        var detector = FireableCollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.fireableCollisions.isEmpty)
        #expect(scene.world.pendingRemovalComponents.entities == [pendingEntity.id])
        #expect(scene.world.entity(for: target.id) === target)
        #expect(scene.world.entity(for: missile.id) === missile)
    }

    @Test func lifetimeClippingRecordsAFractionOfTheCompleteTick() throws {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(40, 0, 0), velocity: .zero)
        let missile = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 0.5)
        scene.move(deltaTime: 1)

        var detector = FireableCollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)

        let contact = try #require(scene.world.fireableCollisions.first)
        #expect(contact.entityID == missile.id)
        #expect(contact.targetEntityID == target.id)
        #expect(abs(contact.tickFraction - 0.38) < 1e-12)
        #expect(scene.world.pendingRemovalComponents.entities.isEmpty)
    }
}
