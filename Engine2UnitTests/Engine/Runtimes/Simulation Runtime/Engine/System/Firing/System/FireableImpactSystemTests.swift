import Testing
@testable import Engine2

struct FireableImpactSystemTests {
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

        var response = FireableImpactSystem()
        response.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.entity(for: asteroid.id) === asteroid)
        #expect(scene.world.entity(for: missile.id) === missile)
        #expect(scene.world.entity(for: asteroid.id)?.lifecycleState == .pendingRemoval)
        #expect(scene.world.entity(for: missile.id)?.lifecycleState == .pendingRemoval)
        #expect(scene.world.renderableComponents[asteroid.id] != nil)
        #expect(scene.world.renderableComponents[missile.id] != nil)
        #expect(scene.world.collisionBodyComponents[asteroid.id] != nil)
        #expect(scene.world.fireableComponents[missile.id] != nil)

        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
        #expect(scene.world.renderableComponents[asteroid.id] == nil)
        #expect(scene.world.renderableComponents[missile.id] == nil)
        #expect(scene.world.collisionBodyComponents[asteroid.id] == nil)
        #expect(scene.world.fireableComponents.entities.isEmpty)
        #expect(scene.world.entity(for: scene.skiff.id) === scene.skiff)
    }

    @Test func earliestImpactDestroysTheDepotAndPreservesALaterTarget() {
        var scene = MissileTestScene(velocity: .zero)
        let depot = scene.depot(at: SIMD3<Double>(40, 0, 0))
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = FireableImpactSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: missile.id) == nil)
        #expect(scene.world.entity(for: depot.id) == nil)
        #expect(scene.world.entity(for: asteroid.id) === asteroid)
    }

    @Test func crossingTargetUsesRelativeSweptMotion() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 10, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)
        scene.world.positionComponents.update(for: asteroid.id) { position in
            position.position.y = -10
        }

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = FireableImpactSystem()
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
        var response = FireableImpactSystem()
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
        var response = FireableImpactSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: second.id) == nil)
        #expect(scene.world.fireableComponents.entities.isEmpty)
    }

    @Test func overlappingOwnerAndOtherMissilesAreIgnored() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        let second = scene.missile(at: .zero, velocity: .zero, lifetime: 5)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = FireableImpactSystem()
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
        var response = FireableImpactSystem()
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
        var response = FireableImpactSystem()
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
        scene.world.positionComponents.update(for: asteroid.id) { position in
            position.position.y = -50
        }

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = FireableImpactSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
    }

    @Test func unownedNonexpiringFiredBodyDestroysATarget() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let fired = PhysicalFireableTestEntity(
            in: scene.world,
            from: fireableState()
        )
        scene.move(deltaTime: 1)
        #expect(scene.world.ownershipComponents[fired.id] == nil)
        #expect(scene.world.lifetimeComponents[fired.id] == nil)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = FireableImpactSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: fired.id) == nil)
    }

    @Test func unownedFiredBodyAndDepotAreBothDestroyedOnImpact() {
        var scene = MissileTestScene(velocity: .zero)
        let blocker = scene.depot(at: SIMD3<Double>(40, 0, 0))
        let fired = PhysicalFireableTestEntity(
            in: scene.world,
            from: fireableState()
        )
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = FireableImpactSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: fired.id) == nil)
        #expect(scene.world.entity(for: blocker.id) == nil)
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
        var response = FireableImpactSystem()
        response.update(world: &scene.world, deltaTime: 1)
        var removal = EntityRemovalSystem()
        removal.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: missile.id) == nil)
        #expect(scene.world.entity(for: scene.skiff.id) == nil)
        #expect(scene.world.selectedEntityID == nil)
    }

    @Test func targetExpiringBeforeContactDoesNotConsumeTheFiredBody() {
        var scene = MissileTestScene(velocity: .zero)
        let target = expiringTarget(at: SIMD3<Double>(60, 0, 0), lifetime: 0.25, in: scene.world)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = FireableImpactSystem()
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
        var response = FireableImpactSystem()
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
        scene.world.lifetimeComponents.update(for: target.id) { lifetime in
            lifetime.remainingLifetime = 0
        }

        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        var response = FireableImpactSystem()
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
        scene.world.positionComponents.update(for: target.id) { position in
            position.position = SIMD3<Double>(1_000, 1_000, 0)
        }
        scene.world.previousPositionComponents.update(for: target.id) { previous in
            previous.position = SIMD3<Double>(1_000, 1_000, 0)
        }
        scene.world.lifetimeComponents.update(for: missile.id) { lifetime in
            lifetime.remainingLifetime = 0
        }

        var response = FireableImpactSystem()
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

        var response = FireableImpactSystem()
        response.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.collisionContacts.isEmpty)
        #expect(scene.world.registeredEntities.allSatisfy { $0.lifecycleState == .active })
        #expect(scene.world.entity(for: target.id) === target)
        #expect(scene.world.entity(for: missile.id) === missile)
    }

    @Test func ownerAndFiredContactsDoNotHideALaterEligibleTarget() {
        var scene = MissileTestScene(velocity: .zero)
        let missile = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        let otherMissile = scene.missile(at: SIMD3<Double>(20, 0, 0), velocity: .zero, lifetime: 5)
        let target = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        scene.move(deltaTime: 1)
        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        #expect(scene.world.collisionContacts.count >= 3)

        var response = FireableImpactSystem()
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
        #expect(pending.markForRemoval())

        var response = FireableImpactSystem()
        response.update(world: &scene.world, deltaTime: 1)

        #expect(missile.lifecycleState == .pendingRemoval)
        #expect(target.lifecycleState == .pendingRemoval)
        #expect(pending.lifecycleState == .pendingRemoval)
    }

    @Test func ordinaryCollisionDoesNotApplyFiredImpactPolicy() {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: .zero, velocity: .zero)
        var detector = CollisionSystem()
        detector.update(world: &scene.world, deltaTime: 1)
        #expect(!scene.world.collisionContacts.isEmpty)

        var response = FireableImpactSystem()
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
                collisionRestitution: 0,
                lifetime: lifetime
            )
        )
    }

    private func fireableState() -> Entity.InitialState {
        Entity.InitialState(
            position: SIMD3<Double>(10, 0, 0),
            velocity: SIMD3<Double>(100, 0, 0),
            collisionRadius: 1,
            collisionRestitution: 0
        )
    }
}
