import Testing
import simd
@testable import Engine2

struct OrbitCircularizationSystemTests {
    @Test func successfulCommandEngagesWithoutChangingMotionOrFuel() throws {
        var fixture = makeFixture(remainingFuel: 2_000)
        let originalMotion = try #require(fixture.world.motionComponents[fixture.entity])
        let originalFuel = try #require(fixture.world.fuelComponents[fixture.entity])
        let estimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )
        fixture.world.orbitCircularizationCommand = OrbitCircularizationCommand(
            entityID: fixture.entity
        )

        var system = OrbitCircularizationSystem()
        system.update(world: &fixture.world, deltaTime: 1.0 / 60)

        #expect(fixture.world.orbitCircularizationCommand == nil)
        #expect(
            fixture.world.orbitCircularizationAutopilotComponents[fixture.entity]
                == .engaged(direction: estimate.direction)
        )
        #expect(fixture.world.motionComponents[fixture.entity] == originalMotion)
        #expect(fixture.world.fuelComponents[fixture.entity] == originalFuel)
        #expect(fixture.world.playerControlComponents[fixture.entity]?.translation == .zero)
    }

    @Test func insufficientFuelConsumesCommandWithoutChangingPhysicalOrControlState() throws {
        var fixture = makeFixture(remainingFuel: 1)
        let originalMotion = try #require(fixture.world.motionComponents[fixture.entity])
        let originalFuel = try #require(fixture.world.fuelComponents[fixture.entity])
        let originalControl = try #require(fixture.world.playerControlComponents[fixture.entity])
        let estimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )
        #expect(!estimate.hasSufficientFuel)
        fixture.world.orbitCircularizationCommand = OrbitCircularizationCommand(
            entityID: fixture.entity
        )

        var system = OrbitCircularizationSystem()
        system.update(world: &fixture.world, deltaTime: 1.0 / 60)

        #expect(fixture.world.orbitCircularizationCommand == nil)
        #expect(fixture.world.orbitCircularizationAutopilotComponents[fixture.entity] == .idle)
        #expect(fixture.world.motionComponents[fixture.entity] == originalMotion)
        #expect(fixture.world.fuelComponents[fixture.entity] == originalFuel)
        #expect(fixture.world.playerControlComponents[fixture.entity] == originalControl)
    }

    @Test func repeatedCommandPreservesTheEngagedManeuverAndPhysicalState() throws {
        var fixture = makeFixture(remainingFuel: 2_000)
        fixture.world.orbitCircularizationCommand = OrbitCircularizationCommand(
            entityID: fixture.entity
        )
        var system = OrbitCircularizationSystem()
        system.update(world: &fixture.world, deltaTime: 1.0 / 60)
        let engagedState = try #require(
            fixture.world.orbitCircularizationAutopilotComponents[fixture.entity]
        )

        fixture.world.playerControlComponents.update(for: fixture.entity) {
            $0.translation = SIMD2<Double>(-1, 1)
        }
        fixture.world.orbitCircularizationCommand = OrbitCircularizationCommand(
            entityID: fixture.entity
        )
        let originalMotion = try #require(fixture.world.motionComponents[fixture.entity])
        let originalFuel = try #require(fixture.world.fuelComponents[fixture.entity])

        system.update(world: &fixture.world, deltaTime: 1.0 / 60)

        #expect(fixture.world.orbitCircularizationCommand == nil)
        #expect(
            fixture.world.orbitCircularizationAutopilotComponents[fixture.entity]
                == engagedState
        )
        #expect(fixture.world.motionComponents[fixture.entity] == originalMotion)
        #expect(fixture.world.fuelComponents[fixture.entity] == originalFuel)
        #expect(fixture.world.playerControlComponents[fixture.entity]?.translation == .zero)
    }

    private func makeFixture(
        remainingFuel: Double
    ) -> (world: World, primary: EntityID, entity: EntityID) {
        let world = World()
        let primary = EntityID(index: 0, generation: 0)
        let entity = EntityID(index: 1, generation: 0)

        world.positionComponents.insert(PositionComponent(position: .zero), for: primary)
        world.gravitySourceComponents.insert(
            GravitySourceComponent(gravitationalParameter: 4_000_000),
            for: primary
        )
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 100, restitution: 0.35),
            for: primary
        )
        world.positionComponents.insert(
            PositionComponent(position: SIMD3<Double>(1_200, 0, 0)),
            for: entity
        )
        world.motionComponents.insert(
            MotionComponent(velocity: .zero, impulse: SIMD3<Double>(1, 2, 3)),
            for: entity
        )
        world.orbitPrimaryComponents.insert(
            OrbitPrimaryComponent(primaryEntityID: primary),
            for: entity
        )
        world.orbitCircularizationAutopilotComponents.insert(.idle, for: entity)
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 10, restitution: 0.35),
            for: entity
        )
        world.massComponents.insert(MassComponent(dryMass: 10_000), for: entity)
        world.propulsionComponents.insert(
            PropulsionComponent(maximumThrust: 300_000, exhaustVelocity: 20_000),
            for: entity
        )
        world.fuelComponents.insert(
            FuelComponent(capacity: 2_000, remaining: remainingFuel),
            for: entity
        )
        world.playerControlComponents.insert(
            PlayerControlComponent(translation: SIMD2<Double>(1, -1)),
            for: entity
        )

        return (world, primary, entity)
    }
}
