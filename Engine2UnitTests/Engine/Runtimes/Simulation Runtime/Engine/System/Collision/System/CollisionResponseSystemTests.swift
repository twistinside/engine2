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
        world.collisionBodyComponents.insert(CollisionBodyComponent(radius: 1, response: .sensor), for: sensor)
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.collisionContacts.count == 1)
        var response = CollisionResponseSystem()

        response.update(world: &world, deltaTime: 1)

        #expect(world.positionComponents[solid]?.position == .zero)
        #expect(world.motionComponents[solid]?.velocity == .zero)
        #expect(world.positionComponents[sensor]?.position == SIMD3<Double>(10, 0, 0))
        #expect(world.motionComponents[sensor]?.velocity == SIMD3<Double>(20, 0, 0))
        #expect(world.contactDamageComponents.entities.isEmpty)
        #expect(world.contactConsumptionComponents.entities.isEmpty)
    }

    @Test func pendingRemovalBodyRetainsItsMotionWithoutBouncing() {
        var world = World()
        let body = Entity(in: world, from: .empty).id
        let obstacle = Entity(in: world, from: .empty).id
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: body)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: SIMD3<Double>(-10, 0, 0)), for: body)
        world.motionComponents.insert(MotionComponent(velocity: SIMD3<Double>(20, 0, 0)), for: body)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
            for: body
        )
        world.positionComponents.insert(PositionComponent(position: .zero), for: obstacle)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: .zero), for: obstacle)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
            for: obstacle
        )

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.destructibleComponents.update(for: body) { $0.state = .pendingRemoval })
        var system = CollisionResponseSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.positionComponents[body]?.position == SIMD3<Double>(10, 0, 0))
        #expect(world.motionComponents[body]?.velocity == SIMD3<Double>(20, 0, 0))
        #expect(world.collisionBodyComponents[body] != nil)
        #expect(world.entity(for: body)?.lifecycleState == .pendingRemoval)
    }

    @Test func pendingRemovalObstacleDoesNotBlockALaterCollision() {
        var world = World()
        let body = Entity(in: world, from: .empty).id
        let pending = Entity(in: world, from: .empty).id
        let surviving = Entity(in: world, from: .empty).id
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: body)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: SIMD3<Double>(-10, 0, 0)), for: body)
        world.motionComponents.insert(MotionComponent(velocity: SIMD3<Double>(20, 0, 0)), for: body)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
            for: body
        )
        for (obstacle, position) in [(pending, SIMD3<Double>.zero), (surviving, SIMD3<Double>(5, 0, 0))] {
            world.positionComponents.insert(PositionComponent(position: position), for: obstacle)
            world.previousPositionComponents.insert(PreviousPositionComponent(position: position), for: obstacle)
            world.collisionBodyComponents.insert(
                CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
                for: obstacle
            )
        }

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.destructibleComponents.update(for: pending) { $0.state = .pendingRemoval })
        var system = CollisionResponseSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.positionComponents[body]?.position == SIMD3<Double>(3, 0, 0))
        #expect(world.motionComponents[body]?.velocity == SIMD3<Double>(-20, 0, 0))
        #expect(world.collisionBodyComponents[pending] != nil)
        #expect(world.entity(for: pending)?.lifecycleState == .pendingRemoval)
    }

    @Test func detectsTunnelingAndBouncesWithConfiguredRestitution() {
        var world = World()
        let skiff = Entity(in: world, from: .empty).id
        let obstacle = Entity(in: world, from: .empty).id
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: skiff)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: SIMD3<Double>(-10, 0, 0)), for: skiff)
        world.motionComponents.insert(MotionComponent(velocity: SIMD3<Double>(20, 0, 0)), for: skiff)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 0.35)),
            for: skiff
        )
        world.positionComponents.insert(PositionComponent(position: .zero), for: obstacle)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: .zero), for: obstacle)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 0.35)),
            for: obstacle
        )

        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        var system = CollisionResponseSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.positionComponents[skiff]?.position == SIMD3<Double>(-2, 0, 0))
        #expect(world.motionComponents[skiff]?.velocity == SIMD3<Double>(-7, 0, 0))
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
        world.positionComponents.insert(PositionComponent(position: .zero), for: star)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: skiff)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: SIMD3<Double>(-10, 0, 0)), for: skiff)
        world.motionComponents.insert(MotionComponent(velocity: SIMD3<Double>(20, 5, 0)), for: skiff)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 0.35)),
            for: skiff
        )
        world.positionComponents.insert(PositionComponent(position: .zero), for: obstacle)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: .zero), for: obstacle)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 0.35)),
            for: obstacle
        )
        world.orbitalRailComponents.insert(
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

        #expect(world.motionComponents[skiff]?.velocity == SIMD3<Double>(-7, 5, 0))
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

        #expect(world.positionComponents[moving]?.position == SIMD3<Double>(-2, 0, 0))
        #expect(world.motionComponents[moving]?.velocity == SIMD3<Double>(-20, 0, 0))
        #expect(world.positionComponents[behindWall]?.position == SIMD3<Double>(5, 0, 0))
        #expect(world.motionComponents[behindWall]?.velocity == .zero)
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

        #expect(world.positionComponents[overlapping]?.position == SIMD3<Double>(2, 0, 0))
        #expect(world.positionComponents[nearby]?.position == SIMD3<Double>(4, 0, 0))
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
        world.lifetimeComponents.insert(LifetimeComponent(remainingLifetime: 1.5), for: moving)
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        var lifetime = LifetimeSystem()
        lifetime.update(world: &world, deltaTime: 1)
        #expect(world.lifetimeComponents[moving]?.remainingLifetime == 0.5)

        var response = CollisionResponseSystem()
        response.update(world: &world, deltaTime: 1)

        #expect(world.positionComponents[moving]?.position == SIMD3<Double>(4, 0, 0))
        #expect(world.motionComponents[moving]?.velocity == SIMD3<Double>(10, 0, 0))
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

        #expect(world.positionComponents[moving]?.position == SIMD3<Double>(2, 0, 0))
        #expect(world.motionComponents[moving]?.velocity == SIMD3<Double>(20, 0, 0))
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
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 0)),
            for: first
        )
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)

        var response = CollisionResponseSystem()
        response.update(world: &world, deltaTime: 1)

        #expect(world.positionComponents[moving]?.position == SIMD3<Double>(-2, 0, 0))
        #expect(world.motionComponents[moving]?.velocity == .zero)
    }

    private func addCollisionBody(
        in world: World,
        from previousPosition: SIMD3<Double>,
        to position: SIMD3<Double>,
        velocity: SIMD3<Double>? = nil
    ) -> EntityID {
        let entity = Entity(in: world, from: .empty)
        world.positionComponents.insert(PositionComponent(position: position), for: entity.id)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: previousPosition), for: entity.id)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 1, response: .solid(restitution: 1)),
            for: entity.id
        )
        if let velocity {
            world.motionComponents.insert(MotionComponent(velocity: velocity), for: entity.id)
        }
        return entity.id
    }
}
