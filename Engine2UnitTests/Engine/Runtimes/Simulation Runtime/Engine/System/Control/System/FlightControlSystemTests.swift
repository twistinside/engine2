import Testing
import simd
@testable import Engine2

struct FlightControlSystemTests {
    @Test func maximumThrustProducesLessAccelerationAtLoadedMass() {
        var world = World()
        let lightSkiff = EntityID(index: 0, generation: 0)
        let loadedSkiff = EntityID(index: 1, generation: 0)
        addControlledSkiff(lightSkiff, cargoOre: 0, to: world)
        addControlledSkiff(loadedSkiff, cargoOre: 8_000, to: world)

        var system = FlightControlSystem(targetSpeed: 90, responseTime: 2)
        system.update(world: &world, deltaTime: 1)

        #expect(
            world.massComponents[lightSkiff]?.totalMass(
                fuel: world.fuelComponents[lightSkiff],
                cargo: world.cargoComponents[lightSkiff]
            ) == 11_985
        )
        #expect(
            world.massComponents[loadedSkiff]?.totalMass(
                fuel: world.fuelComponents[loadedSkiff],
                cargo: world.cargoComponents[loadedSkiff]
            ) == 19_985
        )
        #expect(world.motionComponents[lightSkiff]?.acceleration == SIMD3<Double>(25, 0, 0))
        #expect(world.motionComponents[loadedSkiff]?.acceleration == SIMD3<Double>(15, 0, 0))
        #expect(world.fuelComponents[lightSkiff]?.remaining == 1_985)
        #expect(world.fuelComponents[loadedSkiff]?.remaining == 1_985)
    }

    @Test func screenDirectionUsesTheAuthoritativeCameraOrientation() {
        var world = World()
        let skiff = EntityID(index: 0, generation: 0)
        addControlledSkiff(skiff, cargoOre: 0, to: world)
        world.camera = Camera(
            position: SIMD3<Float>(0, 0, 500),
            rotation: simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1)),
            projection: .perspective(verticalFieldOfView: .pi / 3, near: 1, far: 10_000)
        )

        var system = FlightControlSystem(targetSpeed: 90, responseTime: 2)
        system.update(world: &world, deltaTime: 1)

        let acceleration = world.motionComponents[skiff]?.acceleration ?? SIMD3<Double>(repeating: .nan)
        #expect(abs(acceleration.x) < 1e-5)
        #expect(abs(acceleration.y - 25) < 1e-5)
    }

    private func addControlledSkiff(_ entity: EntityID, cargoOre: Double, to world: World) {
        world.playerControlComponents.insert(PlayerControlComponent(translation: SIMD2<Double>(1, 0)), for: entity)
        world.propulsionComponents.insert(PropulsionComponent(maximumThrust: 300_000, exhaustVelocity: 20_000), for: entity)
        world.fuelComponents.insert(FuelComponent(capacity: 2_000, remaining: 2_000), for: entity)
        world.cargoComponents.insert(CargoComponent(capacity: 8_000, ore: cargoOre), for: entity)
        world.massComponents.insert(MassComponent(dryMass: 10_000), for: entity)
        world.motionComponents.insert(MotionComponent(), for: entity)
    }
}
