import Testing
@testable import Engine2

struct CollisionResponseSystemTests {
    @Test func harmlessSensorsRecordContactWithoutBouncingOrPushingASolidBody() {
        var world = World()
        let solid = addCollisionBody(in: world, from: .zero, to: .zero, velocity: .zero)
        let sensor = addCollisionBody(
            in: world,
            from: SIMD3<Double>(-10, 0, 0),
            to: SIMD3<Double>(10, 0, 0),
            velocity: SIMD3<Double>(20, 0, 0)
        )
        world.components[CollisionBodyComponent.self].insert(CollisionBodyComponent(radius: 1, response: .sensor), for: sensor)
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.collisionContacts.count == 1)
        var response = CollisionResponseSystem()

        response.update(world: &world, deltaTime: 1)

        #expect(world.components[PositionComponent.self][solid]?.position == .zero)
        #expect(world.components[MotionComponent.self][solid]?.velocity == .zero)
        #expect(world.components[PositionComponent.self][sensor]?.position == SIMD3<Double>(10, 0, 0))
        #expect(world.components[MotionComponent.self][sensor]?.velocity == SIMD3<Double>(20, 0, 0))
        #expect(world.components[ContactDamageComponent.self].entities.isEmpty)
        #expect(world.components[ContactConsumptionComponent.self].entities.isEmpty)
    }

    @Test func pendingRemovalBodyRetainsItsMotionWithoutBouncing() {
        var world = World()
        let body = Entity(in: world, from: .empty).id
        let obstacle = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: body)
        world.components[PreviousPositionComponent.self].insert(PreviousPositionComponent(position: SIMD3<Double>(-10, 0, 0)), for: body)
        world.components[MotionComponent.self].insert(MotionComponent(velocity: SIMD3<Double>(20, 0, 0)), for: body)
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
            for: body
        )
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: obstacle)
        world.components[PreviousPositionComponent.self].insert(PreviousPositionComponent(position: .zero), for: obstacle)
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
            for: obstacle
        )

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.components[DestructibleComponent.self].update(for: body) { $0.state = .pendingRemoval })
        var system = CollisionResponseSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[PositionComponent.self][body]?.position == SIMD3<Double>(10, 0, 0))
        #expect(world.components[MotionComponent.self][body]?.velocity == SIMD3<Double>(20, 0, 0))
        #expect(world.components[CollisionBodyComponent.self][body] != nil)
        #expect(world.entity(for: body)?.lifecycleState == .pendingRemoval)
    }

    @Test func pendingRemovalObstacleDoesNotBlockALaterCollision() {
        var world = World()
        let body = Entity(in: world, from: .empty).id
        let pending = Entity(in: world, from: .empty).id
        let surviving = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: body)
        world.components[PreviousPositionComponent.self].insert(PreviousPositionComponent(position: SIMD3<Double>(-10, 0, 0)), for: body)
        world.components[MotionComponent.self].insert(MotionComponent(velocity: SIMD3<Double>(20, 0, 0)), for: body)
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
            for: body
        )
        for (obstacle, position) in [(pending, SIMD3<Double>.zero), (surviving, SIMD3<Double>(5, 0, 0))] {
            world.components[PositionComponent.self].insert(PositionComponent(position: position), for: obstacle)
            world.components[PreviousPositionComponent.self].insert(PreviousPositionComponent(position: position), for: obstacle)
            world.components[CollisionBodyComponent.self].insert(
                CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
                for: obstacle
            )
        }

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.components[DestructibleComponent.self].update(for: pending) { $0.state = .pendingRemoval })
        var system = CollisionResponseSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[PositionComponent.self][body]?.position == SIMD3<Double>(3, 0, 0))
        #expect(world.components[MotionComponent.self][body]?.velocity == SIMD3<Double>(-20, 0, 0))
        #expect(world.components[CollisionBodyComponent.self][pending] != nil)
        #expect(world.entity(for: pending)?.lifecycleState == .pendingRemoval)
    }

    @Test func detectsTunnelingAndBouncesWithConfiguredRestitution() {
        var world = World()
        let skiff = Entity(in: world, from: .empty).id
        let obstacle = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: skiff)
        world.components[PreviousPositionComponent.self].insert(PreviousPositionComponent(position: SIMD3<Double>(-10, 0, 0)), for: skiff)
        world.components[MotionComponent.self].insert(MotionComponent(velocity: SIMD3<Double>(20, 0, 0)), for: skiff)
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 0.35)),
            for: skiff
        )
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: obstacle)
        world.components[PreviousPositionComponent.self].insert(PreviousPositionComponent(position: .zero), for: obstacle)
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 0.35)),
            for: obstacle
        )

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        var system = CollisionResponseSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[PositionComponent.self][skiff]?.position == SIMD3<Double>(-2, 0, 0))
        #expect(world.components[MotionComponent.self][skiff]?.velocity == SIMD3<Double>(-7, 0, 0))
    }

    @Test func missilesDoNotBounceOrPushDynamicBodies() {
        var scene = MissileTestScene(velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(-10, 0, 0), velocity: SIMD3<Double>(20, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var system = CollisionResponseSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.skiff.position == .zero)
        #expect(scene.skiff.velocity == .zero)
        #expect(missile.position == SIMD3<Double>(10, 0, 0))
        #expect(missile.velocity == SIMD3<Double>(20, 0, 0))
    }

    @Test func railVelocityParticipatesInRelativeBounce() {
        var world = World()
        let star = Entity(in: world, from: .empty).id
        let skiff = Entity(in: world, from: .empty).id
        let obstacle = Entity(in: world, from: .empty).id
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: star)
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: skiff)
        world.components[PreviousPositionComponent.self].insert(PreviousPositionComponent(position: SIMD3<Double>(-10, 0, 0)), for: skiff)
        world.components[MotionComponent.self].insert(MotionComponent(velocity: SIMD3<Double>(20, 5, 0)), for: skiff)
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 0.35)),
            for: skiff
        )
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: obstacle)
        world.components[PreviousPositionComponent.self].insert(PreviousPositionComponent(position: .zero), for: obstacle)
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 0.35)),
            for: obstacle
        )
        world.components[OrbitalRailComponent.self].insert(
            OrbitalRailComponent(
                primaryEntityID: star,
                radius: 1,
                angularSpeed: 1,
                phase: 0,
                velocity: SIMD3<Double>(0, 5, 0)
            ),
            for: obstacle
        )

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        var system = CollisionResponseSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[MotionComponent.self][skiff]?.velocity == SIMD3<Double>(-7, 5, 0))
    }

    @Test func earlierWallBounceInvalidatesTheContactWithABodyBeyondTheWall() {
        var world = World()
        let moving = addCollisionBody(
            in: world,
            from: SIMD3<Double>(-10, 0, 0),
            to: SIMD3<Double>(10, 0, 0),
            velocity: SIMD3<Double>(20, 0, 0)
        )
        let behindWall = addCollisionBody(
            in: world,
            from: SIMD3<Double>(5, 0, 0),
            to: SIMD3<Double>(5, 0, 0),
            velocity: .zero
        )
        _ = addCollisionBody(in: world, from: .zero, to: .zero)
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.collisionContacts.count == 2)

        var response = CollisionResponseSystem()
        response.update(world: &world, deltaTime: 1)

        #expect(world.components[PositionComponent.self][moving]?.position == SIMD3<Double>(-2, 0, 0))
        #expect(world.components[MotionComponent.self][moving]?.velocity == SIMD3<Double>(-20, 0, 0))
        #expect(world.components[PositionComponent.self][behindWall]?.position == SIMD3<Double>(5, 0, 0))
        #expect(world.components[MotionComponent.self][behindWall]?.velocity == .zero)
        #expect(world.collisionContacts.count == 2)
        #expect(world.collisionSweeps.first?.position == SIMD2<Double>(10, 0))
    }

    @Test func correctionDiscoversAContactAbsentFromTheOriginalPairList() {
        var world = World()
        let overlapping = addCollisionBody(in: world, from: .zero, to: .zero, velocity: .zero)
        let nearby = addCollisionBody(
            in: world,
            from: SIMD3<Double>(3.5, 0, 0),
            to: SIMD3<Double>(3.5, 0, 0),
            velocity: .zero
        )
        _ = addCollisionBody(in: world, from: .zero, to: .zero)
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.collisionContacts.count == 1)

        var response = CollisionResponseSystem()
        response.update(world: &world, deltaTime: 1)

        #expect(world.components[PositionComponent.self][overlapping]?.position == SIMD3<Double>(2, 0, 0))
        #expect(world.components[PositionComponent.self][nearby]?.position == SIMD3<Double>(4, 0, 0))
        #expect(world.collisionContacts.count == 1)
    }

    @Test func correctedPathUsesLifetimeFromBeforeItsCountdown() {
        var world = World()
        _ = addCollisionBody(in: world, from: .zero, to: .zero, velocity: .zero)
        let moving = addCollisionBody(
            in: world,
            from: SIMD3<Double>(10, 0, 0),
            to: .zero,
            velocity: SIMD3<Double>(-10, 0, 0)
        )
        _ = addCollisionBody(in: world, from: .zero, to: .zero)
        world.components[LifetimeComponent.self].insert(LifetimeComponent(remainingLifetime: 1.5), for: moving)
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        var lifetime = LifetimeSystem()
        lifetime.update(world: &world, deltaTime: 1)
        #expect(world.components[LifetimeComponent.self][moving]?.remainingLifetime == 0.5)

        var response = CollisionResponseSystem()
        response.update(world: &world, deltaTime: 1)

        #expect(world.components[PositionComponent.self][moving]?.position == SIMD3<Double>(4, 0, 0))
        #expect(world.components[MotionComponent.self][moving]?.velocity == SIMD3<Double>(10, 0, 0))
        #expect(world.entity(for: moving)?.lifecycleState == .active)
    }

    @Test func dynamicSecondParticipantUsesTheOppositeContactNormal() {
        var world = World()
        _ = addCollisionBody(in: world, from: .zero, to: .zero)
        let moving = addCollisionBody(
            in: world,
            from: SIMD3<Double>(10, 0, 0),
            to: SIMD3<Double>(-10, 0, 0),
            velocity: SIMD3<Double>(-20, 0, 0)
        )
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.collisionContacts.first?.secondEntityID == moving)

        var response = CollisionResponseSystem()
        response.update(world: &world, deltaTime: 1)

        #expect(world.components[PositionComponent.self][moving]?.position == SIMD3<Double>(2, 0, 0))
        #expect(world.components[MotionComponent.self][moving]?.velocity == SIMD3<Double>(20, 0, 0))
    }

    @Test func equalContactTimesUseTheLowerObstacleIdentity() {
        var world = World()
        let first = addCollisionBody(in: world, from: .zero, to: .zero)
        _ = addCollisionBody(in: world, from: .zero, to: .zero)
        let moving = addCollisionBody(
            in: world,
            from: SIMD3<Double>(-10, 0, 0),
            to: SIMD3<Double>(10, 0, 0),
            velocity: SIMD3<Double>(20, 0, 0)
        )
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 0)),
            for: first
        )
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)

        var response = CollisionResponseSystem()
        response.update(world: &world, deltaTime: 1)

        #expect(world.components[PositionComponent.self][moving]?.position == SIMD3<Double>(-2, 0, 0))
        #expect(world.components[MotionComponent.self][moving]?.velocity == .zero)
    }

    private func addCollisionBody(
        in world: World,
        from previousPosition: SIMD3<Double>,
        to position: SIMD3<Double>,
        velocity: SIMD3<Double>? = nil
    ) -> EntityID {
        let entity = Entity(in: world, from: .empty)
        world.components[PositionComponent.self].insert(PositionComponent(position: position), for: entity.id)
        world.components[PreviousPositionComponent.self].insert(PreviousPositionComponent(position: previousPosition), for: entity.id)
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
            for: entity.id
        )
        if let velocity {
            world.components[MotionComponent.self].insert(MotionComponent(velocity: velocity), for: entity.id)
        }
        return entity.id
    }
}
