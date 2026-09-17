import Foundation
import Testing
import simd
@testable import Engine2

struct GravitySystemTests {
    @Test func addsNewtonianAccelerationOnlyToExplicitReceiver() {
        var world = World()
        let star = EntityID(index: 0, generation: 0)
        let skiff = EntityID(index: 1, generation: 0)
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: star)
        world.components[GravitySourceComponent.self].insert(
            GravitySourceComponent(gravitationalParameter: 5_000_000),
            for: star
        )
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(100, 0, 0)), for: skiff)
        var motion = MotionComponent()
        motion.accumulator.acceleration = SIMD3<Double>(1, 2, 0)
        world.components[MotionComponent.self].insert(motion, for: skiff)
        world.components[GravityReceiverComponent.self].insert(GravityReceiverComponent(), for: skiff)

        var system = GravitySystem()
        system.update(world: &world, deltaTime: 1.0 / 60)

        #expect(world.components[MotionComponent.self][skiff]?.acceleration == SIMD3<Double>(-499, 2, 0))
        #expect(world.components[MotionComponent.self][star] == nil)
    }

    @Test func sourceDoesNotAffectMovableEntityWithoutReceiverCapability() {
        var world = World()
        let star = EntityID(index: 0, generation: 0)
        let ordinaryMovable = EntityID(index: 1, generation: 0)
        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: star)
        world.components[GravitySourceComponent.self].insert(GravitySourceComponent(gravitationalParameter: 5_000_000), for: star)
        world.components[PositionComponent.self].insert(PositionComponent(position: SIMD3<Double>(100, 0, 0)), for: ordinaryMovable)
        world.components[MotionComponent.self].insert(MotionComponent(), for: ordinaryMovable)

        var system = GravitySystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.components[MotionComponent.self][ordinaryMovable]?.acceleration == .zero)
    }

    @Test func twentyOrbitSoakRemainsFiniteAndWithinDriftLimits() {
        var world = World()
        let star = EntityID(index: 0, generation: 0)
        let skiff = EntityID(index: 1, generation: 0)
        let gravitationalParameter = MiningWorldBuilder.gravitationalParameter
        let radius = MiningWorldBuilder.depotOrbitRadius
        let circularSpeed = sqrt(gravitationalParameter / radius)
        let period = 2 * Double.pi * sqrt(radius * radius * radius / gravitationalParameter)
        let deltaTime = 1.0 / 60
        let stepCount = Int((20 * period / deltaTime).rounded())
        let initialPosition = SIMD3<Double>(radius, 0, 0)
        let initialVelocity = SIMD3<Double>(0, circularSpeed, 0)
        let initialEnergy = 0.5 * simd_length_squared(initialVelocity) - gravitationalParameter / radius
        let initialAngularMomentum = radius * circularSpeed

        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: star)
        world.components[GravitySourceComponent.self].insert(GravitySourceComponent(gravitationalParameter: gravitationalParameter), for: star)
        world.components[PositionComponent.self].insert(PositionComponent(position: initialPosition), for: skiff)
        world.components[MotionComponent.self].insert(MotionComponent(velocity: initialVelocity), for: skiff)
        world.components[GravityReceiverComponent.self].insert(GravityReceiverComponent(), for: skiff)

        var gravity = GravitySystem()
        var movement = MovementSystem()
        for _ in 0..<stepCount {
            gravity.update(world: &world, deltaTime: deltaTime)
            movement.update(world: &world, deltaTime: deltaTime)
        }

        let finalPosition = world.components[PositionComponent.self][skiff]?.position ?? SIMD3<Double>(repeating: .nan)
        let finalVelocity = world.components[MotionComponent.self][skiff]?.velocity ?? SIMD3<Double>(repeating: .nan)
        let finalRadius = simd_length(finalPosition)
        let finalEnergy = 0.5 * simd_length_squared(finalVelocity) - gravitationalParameter / finalRadius
        let finalAngularMomentum = finalPosition.x * finalVelocity.y - finalPosition.y * finalVelocity.x

        #expect(finalPosition.isFinite)
        #expect(finalVelocity.isFinite)
        #expect(abs(finalRadius - radius) / radius < 0.05)
        #expect(abs(finalEnergy - initialEnergy) / abs(initialEnergy) < 5e-3)
        #expect(abs(finalAngularMomentum - initialAngularMomentum) / initialAngularMomentum < 1e-10)
    }
}
