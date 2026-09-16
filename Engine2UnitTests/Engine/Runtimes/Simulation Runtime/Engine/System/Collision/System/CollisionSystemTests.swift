import Testing
@testable import Engine2

struct CollisionSystemTests {
    @Test func ordinaryBodiesProduceEveryContactWithoutChangingParticipants() {
        var world = World()
        let moving = addCollisionBody(in: world, from: SIMD3<Double>(-10, 0, 0), to: SIMD3<Double>(10, 0, 0))
        let near = addCollisionBody(in: world, from: .zero, to: .zero)
        let far = addCollisionBody(in: world, from: SIMD3<Double>(5, 0, 0), to: SIMD3<Double>(5, 0, 0))
        let registeredIDs = world.registeredEntities.map(\.id)

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)

        #expect(world.contactConsumptionComponents.entities.isEmpty)
        #expect(world.collisionContacts.count == 2)
        #expect(world.collisionContacts.map(\.firstEntityID) == [moving.id, moving.id])
        #expect(world.collisionContacts.map(\.secondEntityID) == [near.id, far.id])
        #expect(world.collisionContacts.map(\.tickFraction) == [0.4, 0.65])
        #expect(world.collisionContacts.map(\.normal) == [SIMD2<Double>(-1, 0), SIMD2<Double>(-1, 0)])
        #expect(world.collisionSweeps.map(\.entityID) == registeredIDs)
        #expect(world.registeredEntities.map(\.id) == registeredIDs)
        #expect(world.registeredEntities.allSatisfy { $0.lifecycleState == .active })
        #expect(world.positionComponents[moving.id]?.position == SIMD3<Double>(10, 0, 0))
        #expect(world.previousPositionComponents[moving.id]?.position == SIMD3<Double>(-10, 0, 0))
    }

    @Test func detectorRetainsOwnerAndSensorPairsForConsumerPolicy() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        let second = scene.missile(at: .zero, velocity: .zero, lifetime: 5)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.collisionContacts.count == 3)
        #expect(scene.world.collisionContacts.contains {
            $0.firstEntityID == scene.skiff.id && $0.secondEntityID == first.id
        })
        #expect(scene.world.collisionContacts.contains {
            $0.firstEntityID == scene.skiff.id && $0.secondEntityID == second.id
        })
        #expect(scene.world.collisionContacts.contains {
            $0.firstEntityID == first.id && $0.secondEntityID == second.id
        })
        #expect(first.lifecycleState == .active)
        #expect(second.lifecycleState == .active)
        #expect(first.remainingLifetime == 5)
    }

    @Test(arguments: [0, -1, Double.infinity, Double.nan])
    func invalidDurationClearsPreviousContactsAndSweeps(deltaTime: Double) {
        var world = World()
        _ = addCollisionBody(in: world, from: SIMD3<Double>(-10, 0, 0), to: SIMD3<Double>(10, 0, 0))
        _ = addCollisionBody(in: world, from: .zero, to: .zero)
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.collisionContacts.count == 1)

        detector.update(world: &world, deltaTime: deltaTime)

        #expect(world.collisionContacts.isEmpty)
        #expect(world.collisionSweeps.isEmpty)
    }

    @Test func removingAllBodiesClearsPreviousCollisionData() {
        var world = World()
        let first = addCollisionBody(in: world, from: SIMD3<Double>(-10, 0, 0), to: SIMD3<Double>(10, 0, 0))
        let second = addCollisionBody(in: world, from: .zero, to: .zero)
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.collisionContacts.count == 1)
        world.destroy(first.id)
        world.destroy(second.id)

        detector.update(world: &world, deltaTime: 1)

        #expect(world.collisionContacts.isEmpty)
        #expect(world.collisionSweeps.isEmpty)
    }

    @Test(arguments: [false, true])
    func pendingParticipantDoesNotProduceAContact(markFirst: Bool) {
        var world = World()
        let first = addCollisionBody(in: world, from: SIMD3<Double>(-10, 0, 0), to: SIMD3<Double>(10, 0, 0))
        let second = addCollisionBody(in: world, from: .zero, to: .zero)
        let pending = markFirst ? first : second
        #expect(world.destructibleComponents.update(for: pending.id) { $0.state = .pendingRemoval })

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)

        #expect(world.collisionContacts.isEmpty)
        #expect(world.collisionSweeps.count == 1)
        #expect(world.collisionSweeps.first?.entityID != pending.id)
        #expect(world.entity(for: pending.id) === pending)
    }

    @Test func lifetimeClippingUsesTheSharedIntervalAndCompleteTickTime() throws {
        var world = World()
        let moving = addCollisionBody(
            in: world, from: .zero, to: SIMD3<Double>(100, 0, 0), lifetime: 0.5
        )
        let crossing = addCollisionBody(
            in: world, from: SIMD3<Double>(50, 50, 0), to: SIMD3<Double>(50, -50, 0), lifetime: 0.75
        )

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)

        let contact = try #require(world.collisionContacts.first)
        #expect(contact.firstEntityID == moving.id)
        #expect(contact.secondEntityID == crossing.id)
        #expect(abs(contact.tickFraction - (0.5 - 2.0.squareRoot() / 100)) < 1e-12)
        #expect(world.lifetimeComponents[moving.id]?.remainingLifetime == 0.5)
        #expect(world.lifetimeComponents[crossing.id]?.remainingLifetime == 0.75)
        #expect(world.collisionSweeps.map(\.travelFraction) == [0.5, 0.75])
    }

    @Test func contactAfterEitherParticipantsLifetimeIsExcluded() {
        var world = World()
        _ = addCollisionBody(in: world, from: .zero, to: SIMD3<Double>(100, 0, 0), lifetime: 1)
        _ = addCollisionBody(
            in: world, from: SIMD3<Double>(60, 0, 0), to: SIMD3<Double>(60, 0, 0), lifetime: 0.25
        )

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)

        #expect(world.collisionContacts.isEmpty)
        #expect(world.collisionSweeps.count == 2)
    }

    @Test func zeroLifetimeCannotCreateAnInitialOverlapContact() {
        var world = World()
        let expired = addCollisionBody(in: world, from: .zero, to: .zero, lifetime: 1)
        let surviving = addCollisionBody(in: world, from: .zero, to: .zero)
        world.lifetimeComponents.update(for: expired.id) { $0.remainingLifetime = 0 }

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)

        #expect(world.collisionContacts.isEmpty)
        #expect(world.collisionSweeps.map(\.entityID) == [surviving.id])
    }

    private func addCollisionBody(
        in world: World,
        from previousPosition: SIMD3<Double>,
        to position: SIMD3<Double>,
        lifetime: Double? = nil
    ) -> Entity {
        let entity = Entity(in: world, from: .empty)
        world.positionComponents.insert(PositionComponent(position: position), for: entity.id)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: previousPosition), for: entity.id)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
            for: entity.id
        )
        if let lifetime {
            world.lifetimeComponents.insert(LifetimeComponent(remainingLifetime: lifetime), for: entity.id)
        }
        return entity
    }
}
