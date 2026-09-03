import Foundation
import Testing
import simd
@testable import Engine2

struct OrbitalRailSystemTests {
    @Test func derivesPositionAndVelocityFromCompleteCircularPhase() {
        var world = World()
        let primary = EntityID(index: 0, generation: 0)
        let satellite = EntityID(index: 1, generation: 0)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(10, 20, 0)), for: primary)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(110, 20, 0)), for: satellite)
        world.orbitalRailComponents.insert(
            OrbitalRailComponent(
                primaryEntityID: primary,
                radius: 100,
                angularSpeed: 0.5,
                phase: 0
            ),
            for: satellite
        )

        var system = OrbitalRailSystem()
        system.update(world: &world, deltaTime: .pi)

        let position = world.positionComponents[satellite]?.position
        let velocity = world.orbitalRailComponents[satellite]?.velocity
        #expect(position.map { simd_length($0 - SIMD3<Double>(10, 120, 0)) < 1e-10 } == true)
        #expect(velocity.map { simd_length($0 - SIMD3<Double>(-50, 0, 0)) < 1e-10 } == true)
    }

    @Test func twentyOrbitsRetainTheAuthoredRadius() {
        var world = World()
        let primary = EntityID(index: 0, generation: 0)
        let satellite = EntityID(index: 1, generation: 0)
        let radius = 1_800.0
        let angularSpeed = sqrt(MiningWorldBuilder.gravitationalParameter / (radius * radius * radius))
        let period = 2 * Double.pi / angularSpeed
        let step = 1.0 / 60
        let stepCount = Int((20 * period / step).rounded())

        world.positionComponents.insert(PositionComponent(position: .zero), for: primary)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(radius, 0, 0)), for: satellite)
        world.orbitalRailComponents.insert(
            OrbitalRailComponent(
                primaryEntityID: primary,
                radius: radius,
                angularSpeed: angularSpeed,
                phase: 0
            ),
            for: satellite
        )

        var system = OrbitalRailSystem()
        for _ in 0..<stepCount {
            system.update(world: &world, deltaTime: step)
        }

        let position = world.positionComponents[satellite]?.position ?? SIMD3<Double>(repeating: .nan)
        #expect(abs(simd_length(position) - radius) < 1e-9)
        #expect(position.isFinite)
    }
}
