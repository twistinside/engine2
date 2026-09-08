import Testing
@testable import Engine2

struct MissileImpactSystemTests {
    @Test func sweptImpactDestroysAsteroidAndProjectileBetweenEndpoints() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var system = MissileImpactSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
        #expect(scene.world.renderableComponents[asteroid.id] == nil)
        #expect(scene.world.renderableComponents[missile.id] == nil)
        #expect(scene.world.collisionBodyComponents[asteroid.id] == nil)
        #expect(scene.world.missileComponents.entities.isEmpty)
        #expect(scene.world.entity(for: scene.skiff.id) === scene.skiff)
    }

    @Test func earliestSolidImpactBlocksADestructibleTarget() {
        var scene = MissileTestScene(velocity: .zero)
        let depot = scene.depot(at: SIMD3<Double>(40, 0, 0))
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var system = MissileImpactSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: missile.id) == nil)
        #expect(scene.world.entity(for: depot.id) === depot)
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

        var system = MissileImpactSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
    }

    @Test func equalImpactTimesUseEntityIdentity() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let second = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        _ = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var system = MissileImpactSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: second.id) === second)
    }

    @Test func missilesHittingTheSameBodyInOneTickAreAllConsumed() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(60, 0, 0), velocity: .zero)
        let first = scene.missile(at: SIMD3<Double>(10, 0, 0), velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        let second = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var system = MissileImpactSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: second.id) == nil)
        #expect(scene.world.missileComponents.entities.isEmpty)
    }

    @Test func overlappingOwnerAndOtherMissilesAreIgnored() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.missile(at: .zero, velocity: .zero, lifetime: 5)
        let second = scene.missile(at: .zero, velocity: .zero, lifetime: 5)

        var system = MissileImpactSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: scene.skiff.id) === scene.skiff)
        #expect(scene.world.entity(for: first.id) === first)
        #expect(scene.world.entity(for: second.id) === second)
        #expect(first.remainingLifetime == 4)
        #expect(second.remainingLifetime == 4)
    }

    @Test func expiryRemovesEveryMissileWithoutSkippingCompactedRows() {
        var scene = MissileTestScene(velocity: .zero)
        let first = scene.missile(at: .zero, velocity: .zero, lifetime: 0.5)
        let second = scene.missile(at: .zero, velocity: .zero, lifetime: 0.5)
        let third = scene.missile(at: .zero, velocity: .zero, lifetime: 0.5)

        var system = MissileImpactSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: first.id) == nil)
        #expect(scene.world.entity(for: second.id) == nil)
        #expect(scene.world.entity(for: third.id) == nil)
        #expect(scene.world.missileComponents.entities.isEmpty)
        #expect(scene.world.motionComponents.entities == [scene.skiff.id])
    }

    @Test func finalLifetimeIntervalStillAllowsAnEarlierHit() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(40, 0, 0), velocity: .zero)
        let missile = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 0.5)
        scene.move(deltaTime: 1)

        var system = MissileImpactSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
    }

    @Test func targetBeyondRemainingLifetimeIsNotHit() {
        var scene = MissileTestScene(velocity: .zero)
        let asteroid = scene.asteroid(at: SIMD3<Double>(80, 0, 0), velocity: .zero)
        let missile = scene.missile(at: .zero, velocity: SIMD3<Double>(100, 0, 0), lifetime: 0.5)
        scene.move(deltaTime: 1)

        var system = MissileImpactSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) === asteroid)
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

        var system = MissileImpactSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.world.entity(for: asteroid.id) == nil)
        #expect(scene.world.entity(for: missile.id) == nil)
    }
}
