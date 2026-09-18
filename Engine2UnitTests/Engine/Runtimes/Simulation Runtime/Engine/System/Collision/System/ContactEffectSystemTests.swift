import Testing
@testable import Engine2

struct ContactEffectSystemTests {
    @Test func genericContactDamageCanAffectADamageableSensor() {
        var world = World()
        let target = CollisionDamageableTestEntity(
            in: world,
            from: Entity.InitialState(
                collisionRadius: 1,
                collisionResponse: .sensor,
                collisionContactScope: .solidBodies,
                health: 2
            )
        )
        let source = PersistentContactDamageTestEntity(
            in: world,
            from: Entity.InitialState(collisionRadius: 1, collisionResponse: .sensor, contactDamage: 1)
        )
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        #expect(world.collisionContacts.count == 1)
        var response = ContactEffectSystem()

        response.update(world: &world, deltaTime: 1)

        #expect(target.health == HitPoints(rawValue: 1))
        #expect(target.lifecycleState == .active)
        #expect(source.lifecycleState == .active)
    }

    @Test(arguments: [CollisionContactScope.allBodies, .solidBodies])
    func sourceScopeChoosesWhetherAnEarlierSensorReceivesContactEffects(scope: CollisionContactScope) {
        var scene = MissileTestScene(velocity: .zero)
        let sensor = CollisionDamageableTestEntity(
            in: scene.world,
            from: Entity.InitialState(
                position: SIMD3<Double>(40, 0, 0),
                collisionRadius: 1,
                collisionResponse: .sensor,
                health: 1
            )
        )
        let solid = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let source = ContactProjectileTestEntity(
            in: scene.world,
            from: Entity.InitialState(
                position: SIMD3<Double>(10, 0, 0),
                velocity: SIMD3<Double>(100, 0, 0),
                collisionRadius: 1,
                collisionResponse: .sensor,
                collisionContactScope: scope,
                contactDamage: 1
            )
        )
        scene.move(deltaTime: 1)
        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.collisionContacts.count == 2)
        var response = ContactEffectSystem()

        response.update(world: &scene.world, deltaTime: 1)

        #expect(source.lifecycleState == .pendingRemoval)
        #expect(sensor.health == (scope == .allBodies ? .zero : HitPoints(rawValue: 1)))
        #expect(sensor.lifecycleState == (scope == .allBodies ? .pendingRemoval : .active))
        #expect(solid.health == (scope == .solidBodies ? .zero : HitPoints(rawValue: 1)))
        #expect(solid.lifecycleState == (scope == .solidBodies ? .pendingRemoval : .active))
    }

    @Test func persistentContactDamageCanExhaustHealthAcrossSeveralTicks() {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(10, 0, 0), velocity: .zero)
        let source = PersistentContactDamageTestEntity(
            in: scene.world,
            from: Entity.InitialState(
                position: SIMD3<Double>(10, 0, 0),
                collisionRadius: 1,
                collisionResponse: .sensor,
                contactDamage: 0.5
            )
        )
        var detector = CollisionSystem()
        var response = ContactEffectSystem()

        detector.update(world: &scene.world, deltaTime: 1)
        response.update(world: &scene.world, deltaTime: 1)

        #expect(target.health == HitPoints(rawValue: 0.5))
        #expect(target.lifecycleState == .active)
        #expect(source.lifecycleState == .active)
        #expect(scene.world.components[ContactConsumptionComponent.self][source.id] == nil)
        #expect(scene.world.components[MotionComponent.self][source.id] == nil)
        #expect(scene.world.components[OwnershipComponent.self][source.id] == nil)
        #expect(scene.world.components[LifetimeComponent.self][source.id] == nil)

        detector.update(world: &scene.world, deltaTime: 1)
        response.update(world: &scene.world, deltaTime: 1)

        #expect(target.health == .zero)
        #expect(target.lifecycleState == .pendingRemoval)
        #expect(source.lifecycleState == .active)
        #expect(scene.world.entity(for: target.id) === target)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.entity(for: target.id) == nil)
        #expect(scene.world.entity(for: source.id) === source)
    }

    @Test func harmlessContactConsumptionLeavesTheRecipientsHealthIntact() {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(10, 0, 0), velocity: .zero)
        let source = HarmlessContactConsumableTestEntity(
            in: scene.world,
            from: Entity.InitialState(
                position: SIMD3<Double>(10, 0, 0),
                collisionRadius: 1,
                collisionResponse: .sensor
            )
        )
        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()

        response.update(world: &scene.world, deltaTime: 1)

        #expect(source.lifecycleState == .pendingRemoval)
        #expect(target.lifecycleState == .active)
        #expect(target.health == HitPoints(rawValue: 1))
        #expect(scene.world.components[ContactDamageComponent.self][source.id] == nil)
        #expect(scene.world.components[MotionComponent.self][source.id] == nil)
        #expect(scene.world.components[OwnershipComponent.self][source.id] == nil)
        #expect(scene.world.components[LifetimeComponent.self][source.id] == nil)
    }

    @Test func simultaneousContactsApplyAllDamageBeforeAnySourceIsRemoved() {
        var world = World()
        let state = Entity.InitialState(
            collisionRadius: 1,
            collisionResponse: .solid(restitution: 0),
            contactDamage: 1,
            health: 1
        )
        let first = ContactDamageableTestEntity(in: world, from: state)
        let second = ContactDamageableTestEntity(in: world, from: state)
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        var response = ContactEffectSystem()

        response.update(world: &world, deltaTime: 1)

        #expect(first.health == .zero)
        #expect(second.health == .zero)
        #expect(first.lifecycleState == .pendingRemoval)
        #expect(second.lifecycleState == .pendingRemoval)
        #expect(world.components[ContactConsumptionComponent.self].entities.isEmpty)
        #expect(world.entity(for: first.id) === first)
        #expect(world.entity(for: second.id) === second)
    }

    @Test func sweptImpactDestroysAsteroidAndProjectileBetweenEndpoints() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.entity(for: asteroid.id) === asteroid)
        #expect(scene.world.entity(for: missile.id) === missile)
        #expect(scene.world.registeredEntities.allSatisfy { $0.lifecycleState == .active })

        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.entity(for: asteroid.id) === asteroid)
        #expect(scene.world.entity(for: missile.id) === missile)
        #expect(scene.world.entity(for: asteroid.id)?.lifecycleState == .pendingRemoval)
        #expect(scene.world.entity(for: missile.id)?.lifecycleState == .pendingRemoval)
        #expect(scene.world.components[RenderableComponent.self][asteroid.id] != nil)
        #expect(scene.world.components[RenderableComponent.self][missile.id] != nil)
        #expect(scene.world.components[CollisionBodyComponent.self][asteroid.id] != nil)
        #expect(scene.world.components[ContactConsumptionComponent.self][missile.id] != nil)

        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
        #expect(scene.world.components[RenderableComponent.self][asteroid.id] == nil)
        #expect(scene.world.components[RenderableComponent.self][missile.id] == nil)
        #expect(scene.world.components[CollisionBodyComponent.self][asteroid.id] == nil)
        #expect(scene.world.components[ContactConsumptionComponent.self].entities.isEmpty)
        #expect(scene.world.entity(for: scene.skiff.id) === scene.skiff)
    }

    @Test func earliestImpactConsumesTheMissileAndPreservesTheImmuneDepotAndLaterTarget() {
        var scene = MissileTestScene(velocity: .zero)
        let depot = scene.depot(at: SIMD3<Double>(40, 0, 0))
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: missile.id) == nil)
        #expect(scene.world.entity(for: depot.id) === depot)
        #expect(depot.lifecycleState == .active)
        #expect(scene.world.components[HealthComponent.self][depot.id] == nil)
        #expect(scene.world.entity(for: asteroid.id) === asteroid)
    }

    @Test func crossingTargetUsesRelativeSweptMotion() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 10, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)
        scene.world.components[PositionComponent.self].update(for: asteroid.id) { position in
            position.position.y = -10
        }

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
    }

    @Test func equalImpactTimesUseEntityIdentity() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let second = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        _ = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: second.id) === second)
    }

    @Test func missilesHittingTheSameBodyInOneTickAreAllConsumed() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let first = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        let second = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: second.id) == nil)
        #expect(scene.world.components[ContactConsumptionComponent.self].entities.isEmpty)
    }

    @Test func overlappingOwnerAndOtherMissilesAreIgnored() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        let second = scene.missile(at: .zero, velocity: .zero, lifetime: 5)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: scene.skiff.id) === scene.skiff)
        #expect(scene.world.entity(for: first.id) === first)
        #expect(scene.world.entity(for: second.id) === second)
        #expect(first.remainingLifetime == 5)
        #expect(second.remainingLifetime == 5)
    }

    @Test func finalLifetimeIntervalStillAllowsAnEarlierHit() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(40, 0, 0), velocity: .zero)
        let missile = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 0.5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
    }

    @Test func targetBeyondRemainingLifetimeIsNotHit() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(80, 0, 0), velocity: .zero)
        let missile = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 0.5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) === asteroid)
        #expect(scene.world.entity(for: missile.id) === missile)
        #expect(missile.remainingLifetime == 0.5)

        var lifetimeSystem = LifetimeSystem()
        lifetimeSystem.update(world: &scene.world, deltaTime: 1)
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: missile.id) == nil)
    }

    @Test func finalLifetimeClipsBothMovingPathsToTheSameInterval() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(50, 50, 0), velocity: .zero)
        let missile = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 0.5)
        scene.move(deltaTime: 1)
        scene.world.components[PositionComponent.self].update(for: asteroid.id) { position in
            position.position.y = -50
        }

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
    }

    @Test func unownedNonexpiringContactProjectileDestroysATarget() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let fired = ContactProjectileTestEntity(
            in: scene.world,
            from: contactProjectileState()
        )
        scene.move(deltaTime: 1)
        #expect(scene.world.components[OwnershipComponent.self][fired.id] == nil)
        #expect(scene.world.components[LifetimeComponent.self][fired.id] == nil)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: fired.id) == nil)
    }

    @Test func unownedContactProjectileIsConsumedWithoutDamagingTheDepot() {
        var scene = MissileTestScene(velocity: .zero)
        let blocker = scene.depot(at: SIMD3<Double>(40, 0, 0))
        let fired = ContactProjectileTestEntity(
            in: scene.world,
            from: contactProjectileState()
        )
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: fired.id) == nil)
        #expect(scene.world.entity(for: blocker.id) === blocker)
        #expect(blocker.lifecycleState == .active)
    }

    @Test func ownerExclusionRequiresTheCompleteGenerationalIdentity() {
        var scene = MissileTestScene(velocity: .zero)
        let otherGeneration = EntityID(index: scene.skiff.id.index, generation: scene.skiff.id.generation + 1)
        let missile = Missile(
            in: scene.world,
            ownerEntityID: otherGeneration,
            position: .zero,
            velocity: .zero,
            radius: 1,
            lifetime: 5
        )

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: missile.id) == nil)
        #expect(scene.world.entity(for: scene.skiff.id) === scene.skiff)
        #expect(scene.skiff.lifecycleState == .active)
        #expect(scene.world.selectedEntityID == scene.skiff.id)
    }

    @Test(arguments: [CollisionOwnerPolicy.include, .exclude])
    func ownershipExclusionFollowsCollisionPolicy(policy: CollisionOwnerPolicy) {
        var scene = MissileTestScene(velocity: .zero)
        let missile = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        scene.world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 1, response: .sensor, ownerPolicy: policy),
            for: missile.id
        )
        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.collisionContacts.count == 1)
        var response = ContactEffectSystem()

        response.update(world: &scene.world, deltaTime: 1)

        #expect(missile.lifecycleState == (policy == .include ? .pendingRemoval : .active))
        #expect(scene.skiff.lifecycleState == .active)
        #expect(scene.world.components[OwnershipComponent.self][missile.id]?.ownerEntityID == scene.skiff.id)
    }

    @Test func aDestructibleStarRemainsImmuneToContactDamage() {
        var world = World()
        let star = Star(
            in: world,
            name: "Star",
            gravitationalParameter: 1,
            mass: 1,
            radius: 1,
            materialID: .goldMetal
        )
        let source = ContactProjectileTestEntity(
            in: world,
            from: Entity.InitialState(
                position: SIMD3<Double>(-10, 0, 0),
                velocity: SIMD3<Double>(20, 0, 0),
                collisionRadius: 1,
                collisionResponse: .sensor,
                contactDamage: 1
            )
        )
        var capture = PreviousPositionCaptureSystem()
        capture.update(world: &world, deltaTime: 1)
        var movement = MovementSystem()
        movement.update(world: &world, deltaTime: 1)
        var detector = CollisionSystem()
        detector.update(world: &world, deltaTime: 1)
        var response = ContactEffectSystem()

        response.update(world: &world, deltaTime: 1)

        #expect(source.lifecycleState == .pendingRemoval)
        #expect(star.lifecycleState == .active)
        #expect(world.components[HealthComponent.self][star.id] == nil)
        #expect(world.entity(for: star.id) === star)
        #expect(world.components[DestructibleComponent.self].update(for: star.id) { $0.state = .pendingRemoval })
        #expect(star.lifecycleState == .pendingRemoval)
    }

    @Test func targetExpiringBeforeContactDoesNotConsumeTheSource() {
        var scene = MissileTestScene(velocity: .zero)
        let target = expiringTarget(at: SIMD3<Double>(60, 0, 0), lifetime: 0.25, in: scene.world)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: target.id) === target)
        #expect(scene.world.entity(for: missile.id) === missile)

        var lifetimeSystem = LifetimeSystem()
        lifetimeSystem.update(world: &scene.world, deltaTime: 1)
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: target.id) == nil)
        #expect(scene.world.entity(for: missile.id) === missile)
    }

    @Test func earliestContactUsesAbsoluteTimeAcrossDifferentTargetLifetimes() {
        var scene = MissileTestScene(velocity: .zero)
        let earlier = expiringTarget(at: SIMD3<Double>(40, 0, 0), lifetime: 0.5, in: scene.world)
        let later = expiringTarget(at: SIMD3<Double>(60, 0, 0), lifetime: 1, in: scene.world)
        let missile = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: earlier.id) == nil)
        #expect(scene.world.entity(for: later.id) === later)
        #expect(scene.world.entity(for: missile.id) == nil)
    }

    @Test func expiredTargetCannotCauseAnInitialOverlapImpact() {
        var scene = MissileTestScene(velocity: .zero)
        let target = expiringTarget(at: SIMD3<Double>(10, 0, 0), lifetime: 1, in: scene.world)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: .zero, lifetime: 5)
        scene.world.components[LifetimeComponent.self].update(for: target.id) { lifetime in
            lifetime.remainingLifetime = 0
        }

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: missile.id) === missile)
    }

    @Test func responseUsesCapturedContactAfterParticipantsMoveApart() throws {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)
        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        let contact = try #require(scene.world.collisionContacts.first)
        scene.world.components[PositionComponent.self].update(for: target.id) { position in
            position.position = SIMD3<Double>(1_000, 1_000, 0)
        }
        scene.world.components[PreviousPositionComponent.self].update(for: target.id) { previous in
            previous.position = SIMD3<Double>(1_000, 1_000, 0)
        }
        scene.world.components[LifetimeComponent.self].update(for: missile.id) { lifetime in
            lifetime.remainingLifetime = 0
        }

        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: target.id)?.lifecycleState == .pendingRemoval)
        #expect(scene.world.entity(for: missile.id)?.lifecycleState == .pendingRemoval)
        #expect(scene.world.entity(for: target.id) === target)
        #expect(scene.world.entity(for: missile.id) === missile)
        #expect(scene.world.collisionContacts.count == 1)
        #expect(scene.world.collisionContacts.first?.firstEntityID == contact.firstEntityID)
        #expect(scene.world.collisionContacts.first?.secondEntityID == contact.secondEntityID)
        #expect(scene.world.collisionContacts.first?.tickFraction == contact.tickFraction)
    }

    @Test func responseDoesNotDiscoverUnrecordedOverlaps() {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(10, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: .zero, lifetime: 5)

        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.collisionContacts.isEmpty)
        #expect(scene.world.registeredEntities.allSatisfy { $0.lifecycleState == .active })
        #expect(scene.world.entity(for: target.id) === target)
        #expect(scene.world.entity(for: missile.id) === missile)
    }

    @Test func ownerAndSensorContactsDoNotHideALaterEligibleTarget() {
        var scene = MissileTestScene(velocity: .zero)
        let missile = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        let otherMissile = scene.missile(at: SIMD3<Double>(20, 0, 0), velocity: .zero, lifetime: 5)
        let target = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        scene.move(deltaTime: 1)
        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.collisionContacts.count >= 3)

        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)

        #expect(missile.lifecycleState == .pendingRemoval)
        #expect(target.lifecycleState == .pendingRemoval)
        #expect(scene.skiff.lifecycleState == .active)
        #expect(otherMissile.lifecycleState == .active)
    }

    @Test func pendingContactDoesNotHideALaterActiveTarget() {
        var scene = MissileTestScene(velocity: .zero)
        let pending = scene.asteroid(at: SIMD3<Double>(40, 0, 0), velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)
        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.components[DestructibleComponent.self].update(for: pending.id) { $0.state = .pendingRemoval })

        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)

        #expect(missile.lifecycleState == .pendingRemoval)
        #expect(target.lifecycleState == .pendingRemoval)
        #expect(pending.lifecycleState == .pendingRemoval)
    }

    @Test func ordinaryCollisionDoesNotCauseDamageOrConsumption() {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: .zero, velocity: .zero)
        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        #expect(!scene.world.collisionContacts.isEmpty)

        var response = ContactEffectSystem()
        response.update(world: &scene.world, deltaTime: 1)

        #expect(target.lifecycleState == .active)
        #expect(scene.skiff.lifecycleState == .active)
    }

    private func expiringTarget(
        at position: SIMD3<Double>,
        lifetime: Double,
        in world: World
    ) -> ExpiringTargetTestEntity {
        ExpiringTargetTestEntity(
            in: world,
            from: Entity.InitialState(
                position: position,
                collisionRadius: 1,
                collisionResponse: .solid(restitution: 0),
                health: 1,
                lifetime: lifetime
            )
        )
    }

    private func contactProjectileState() -> Entity.InitialState {
        Entity.InitialState(
            position: SIMD3<Double>(10, 0, 0),
            velocity: SIMD3<Double>(100, 0, 0),
            collisionRadius: 1,
            collisionResponse: .sensor,
            contactDamage: 1
        )
    }
}
