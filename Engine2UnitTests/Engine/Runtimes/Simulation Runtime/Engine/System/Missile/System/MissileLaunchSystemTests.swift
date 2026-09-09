import simd
import Testing
@testable import Engine2

struct MissileLaunchSystemTests {
    @Test func onePressRegistersOneMissileAndConsumesTheRequest() throws {
        var scene = MissileTestScene(velocity: .zero)
        _ = scene.asteroid(at: SIMD3<Double>(100, 0, 0), velocity: .zero)
        _ = scene.asteroid(at: SIMD3<Double>(0, 200, 0), velocity: .zero)
        scene.world.playerControlComponents.update(for: scene.skiff.id) { control in
            control.isFireRequested = true
        }

        var system = MissileLaunchSystem()
        system.update(world: &scene.world, deltaTime: 1 / 60)

        let missileID = try #require(scene.world.fireableComponents.entities.first)
        let missile = try #require(scene.world.entity(for: missileID) as? Missile)
        #expect(scene.world.fireableComponents.entities.count == 1)
        #expect(missile.ownerEntityID == scene.skiff.id)
        #expect(missile.position == SIMD3<Double>(2, 0, 0))
        #expect(missile.velocity == SIMD3<Double>(100, 0, 0))
        #expect(missile.remainingLifetime == 5)
        #expect(scene.world.previousPositionComponents[missileID]?.position == missile.position)
        #expect(scene.world.renderableComponents[missileID]?.meshID == .ball)
        #expect(scene.world.playerControlComponents[scene.skiff.id]?.isFireRequested == false)

        system.update(world: &scene.world, deltaTime: 1 / 60)

        #expect(scene.world.fireableComponents.entities == [missileID])
    }

    @Test func selectedLauncherIsRequiredAndAnIgnoredPressIsConsumed() {
        var scene = MissileTestScene(velocity: .zero)
        let target = scene.asteroid(at: SIMD3<Double>(100, 0, 0), velocity: .zero)
        var system = MissileLaunchSystem()
        system.update(world: &scene.world, deltaTime: 1 / 60)
        #expect(scene.world.fireableComponents.entities.isEmpty)

        scene.world.select(target.id)
        scene.world.playerControlComponents.update(for: scene.skiff.id) { control in
            control.isFireRequested = true
        }
        system.update(world: &scene.world, deltaTime: 1 / 60)

        #expect(scene.world.fireableComponents.entities.isEmpty)
        #expect(scene.world.playerControlComponents[scene.skiff.id]?.isFireRequested == false)
    }

    @Test func leadsMovingTargetAndInheritsLauncherVelocity() throws {
        var scene = MissileTestScene(velocity: SIMD3<Double>(10, 0, 0))
        _ = scene.asteroid(at: SIMD3<Double>(100, 0, 0), velocity: SIMD3<Double>(0, 10, 0))
        scene.world.playerControlComponents.update(for: scene.skiff.id) { control in
            control.isFireRequested = true
        }

        var system = MissileLaunchSystem()
        system.update(world: &scene.world, deltaTime: 1 / 60)

        let missileID = try #require(scene.world.fireableComponents.entities.first)
        let velocity = try #require(scene.world.motionComponents[missileID]?.velocity)
        #expect(velocity.x > 100)
        #expect(velocity.y > 0)
        #expect(abs(simd_length(velocity - scene.skiff.velocity) - 100) < 1e-10)
    }

    @Test func nearbyFiredDestructibleBodyDoesNotAttractTheNextLaunch() throws {
        var scene = MissileTestScene(velocity: .zero)
        let existing = scene.missile(at: SIMD3<Double>(0, 10, 0), velocity: .zero, lifetime: 5)
        _ = scene.asteroid(at: SIMD3<Double>(100, 0, 0), velocity: .zero)
        #expect(scene.world.destructibleComponents[existing.id] != nil)
        scene.world.playerControlComponents.update(for: scene.skiff.id) { control in
            control.isFireRequested = true
        }

        var system = MissileLaunchSystem()
        system.update(world: &scene.world, deltaTime: 1 / 60)

        let launchedID = try #require(scene.world.fireableComponents.entities.first { $0 != existing.id })
        #expect(scene.world.fireableComponents.entities.count == 2)
        #expect(scene.world.motionComponents[launchedID]?.velocity == SIMD3<Double>(100, 0, 0))
    }

    @Test func equalDistanceTargetsUseEntityIdentity() throws {
        var scene = MissileTestScene(velocity: .zero)
        _ = scene.asteroid(at: SIMD3<Double>(0, 100, 0), velocity: .zero)
        _ = scene.asteroid(at: SIMD3<Double>(100, 0, 0), velocity: .zero)
        scene.world.playerControlComponents.update(for: scene.skiff.id) { control in
            control.isFireRequested = true
        }

        var system = MissileLaunchSystem()
        system.update(world: &scene.world, deltaTime: 1 / 60)

        let missileID = try #require(scene.world.fireableComponents.entities.first)
        #expect(scene.world.motionComponents[missileID]?.velocity == SIMD3<Double>(0, 100, 0))
    }

    @Test func withoutTargetsLaunchesAlongCurrentTravel() throws {
        var scene = MissileTestScene(velocity: SIMD3<Double>(0, 10, 0))
        scene.world.playerControlComponents.update(for: scene.skiff.id) { control in
            control.isFireRequested = true
        }

        var system = MissileLaunchSystem()
        system.update(world: &scene.world, deltaTime: 1 / 60)

        let missileID = try #require(scene.world.fireableComponents.entities.first)
        #expect(scene.world.motionComponents[missileID]?.velocity == SIMD3<Double>(0, 110, 0))
    }
}
