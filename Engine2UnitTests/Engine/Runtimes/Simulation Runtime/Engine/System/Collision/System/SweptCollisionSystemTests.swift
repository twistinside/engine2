import Testing
@testable import Engine2

struct SweptCollisionSystemTests {
    @Test func detectsTunnelingAndBouncesWithConfiguredRestitution() {
        var world = World()
        let skiff = EntityID(index: 0, generation: 0)
        let obstacle = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: skiff)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: SIMD3<Double>(-10, 0, 0)), for: skiff)
        world.motionComponents.insert(MotionComponent(velocity: SIMD3<Double>(20, 0, 0)), for: skiff)
        world.collisionBodyComponents.insert(CollisionBodyComponent(radius: 1, restitution: 0.35), for: skiff)
        world.positionComponents.insert(PositionComponent(position: .zero), for: obstacle)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: .zero), for: obstacle)
        world.collisionBodyComponents.insert(CollisionBodyComponent(radius: 1, restitution: 0.35), for: obstacle)

        var system = SweptCollisionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.positionComponents[skiff]?.position == SIMD3<Double>(-2, 0, 0))
        #expect(world.motionComponents[skiff]?.velocity == SIMD3<Double>(-7, 0, 0))
    }

    @Test func missilesDoNotBounceOrPushDynamicBodies() {
        var scene = MissileTestScene(velocity: .zero)
        let missile = scene.missile(at: SIMD3<Double>(-10, 0, 0), velocity: SIMD3<Double>(20, 0, 0), lifetime: 5)
        scene.move(deltaTime: 1)

        var system = SweptCollisionSystem()
        system.update(world: &scene.world, deltaTime: 1)

        #expect(scene.skiff.position == .zero)
        #expect(scene.skiff.velocity == .zero)
        #expect(missile.position == SIMD3<Double>(10, 0, 0))
        #expect(missile.velocity == SIMD3<Double>(20, 0, 0))
    }

    @Test func railVelocityParticipatesInRelativeBounce() {
        var world = World()
        let star = EntityID(index: 0, generation: 0)
        let skiff = EntityID(index: 1, generation: 0)
        let obstacle = EntityID(index: 2, generation: 0)
        world.positionComponents.insert(PositionComponent(position: .zero), for: star)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(10, 0, 0)), for: skiff)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: SIMD3<Double>(-10, 0, 0)), for: skiff)
        world.motionComponents.insert(MotionComponent(velocity: SIMD3<Double>(20, 5, 0)), for: skiff)
        world.collisionBodyComponents.insert(CollisionBodyComponent(radius: 1, restitution: 0.35), for: skiff)
        world.positionComponents.insert(PositionComponent(position: .zero), for: obstacle)
        world.previousPositionComponents.insert(PreviousPositionComponent(position: .zero), for: obstacle)
        world.collisionBodyComponents.insert(CollisionBodyComponent(radius: 1, restitution: 0.35), for: obstacle)
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

        var system = SweptCollisionSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.motionComponents[skiff]?.velocity == SIMD3<Double>(-7, 5, 0))
    }
}
