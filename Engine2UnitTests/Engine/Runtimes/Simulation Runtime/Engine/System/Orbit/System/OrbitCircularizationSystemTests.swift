import Testing
import simd
@testable import Engine2

struct OrbitCircularizationSystemTests {
    @Test func successfulCommandEngagesWithoutChangingMotionOrFuel() throws {
        var fixture = makeFixture(remainingFuel: 2_000)
        let originalMotion = try #require(fixture.world.components[MotionComponent.self][fixture.entity])
        let originalFuel = try #require(fixture.world.components[FuelComponent.self][fixture.entity])
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
            fixture.world.components[OrbitCircularizationAutopilotComponent.self][fixture.entity]
                == .engaged(direction: estimate.direction)
        )
        #expect(fixture.world.components[MotionComponent.self][fixture.entity] == originalMotion)
        #expect(fixture.world.components[FuelComponent.self][fixture.entity] == originalFuel)
        #expect(fixture.world.components[PlayerControlComponent.self][fixture.entity]?.translation == .zero)
    }

    @Test func insufficientFuelConsumesCommandWithoutChangingPhysicalOrControlState() throws {
        var fixture = makeFixture(remainingFuel: 1)
        let originalMotion = try #require(fixture.world.components[MotionComponent.self][fixture.entity])
        let originalFuel = try #require(fixture.world.components[FuelComponent.self][fixture.entity])
        let originalControl = try #require(fixture.world.components[PlayerControlComponent.self][fixture.entity])
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
        #expect(fixture.world.components[OrbitCircularizationAutopilotComponent.self][fixture.entity] == .idle)
        #expect(fixture.world.components[MotionComponent.self][fixture.entity] == originalMotion)
        #expect(fixture.world.components[FuelComponent.self][fixture.entity] == originalFuel)
        #expect(fixture.world.components[PlayerControlComponent.self][fixture.entity] == originalControl)
    }

    @Test func repeatedCommandPreservesTheEngagedManeuverAndPhysicalState() throws {
        var fixture = makeFixture(remainingFuel: 2_000)
        fixture.world.orbitCircularizationCommand = OrbitCircularizationCommand(
            entityID: fixture.entity
        )
        var system = OrbitCircularizationSystem()
        system.update(world: &fixture.world, deltaTime: 1.0 / 60)
        let engagedState = try #require(
            fixture.world.components[OrbitCircularizationAutopilotComponent.self][fixture.entity]
        )

        fixture.world.components[PlayerControlComponent.self].update(for: fixture.entity) {
            $0.translation = SIMD2<Double>(-1, 1)
        }
        fixture.world.orbitCircularizationCommand = OrbitCircularizationCommand(
            entityID: fixture.entity
        )
        let originalMotion = try #require(fixture.world.components[MotionComponent.self][fixture.entity])
        let originalFuel = try #require(fixture.world.components[FuelComponent.self][fixture.entity])

        system.update(world: &fixture.world, deltaTime: 1.0 / 60)

        #expect(fixture.world.orbitCircularizationCommand == nil)
        #expect(
            fixture.world.components[OrbitCircularizationAutopilotComponent.self][fixture.entity]
                == engagedState
        )
        #expect(fixture.world.components[MotionComponent.self][fixture.entity] == originalMotion)
        #expect(fixture.world.components[FuelComponent.self][fixture.entity] == originalFuel)
        #expect(fixture.world.components[PlayerControlComponent.self][fixture.entity]?.translation == .zero)
    }

    private func makeFixture(
        remainingFuel: Double
    ) -> (world: World, primary: EntityID, entity: EntityID) {
        let world = World()
        let primary = EntityID(index: 0, generation: 0)
        let entity = EntityID(index: 1, generation: 0)

        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: primary)
        world.components[GravitySourceComponent.self].insert(
            GravitySourceComponent(gravitationalParameter: 4_000_000),
            for: primary
        )
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 100, response: .solid(restitution: 0.35)),
            for: primary
        )
        world.components[PositionComponent.self].insert(
            PositionComponent(position: SIMD3<Double>(1_200, 0, 0)),
            for: entity
        )
        world.components[MotionComponent.self].insert(
            MotionComponent(velocity: .zero, impulse: SIMD3<Double>(1, 2, 3)),
            for: entity
        )
        world.components[OrbitPrimaryComponent.self].insert(
            OrbitPrimaryComponent(primaryEntityID: primary),
            for: entity
        )
        world.components[OrbitCircularizationAutopilotComponent.self].insert(.idle, for: entity)
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 10, response: .solid(restitution: 0.35)),
            for: entity
        )
        world.components[MassComponent.self].insert(MassComponent(dryMass: 10_000), for: entity)
        world.components[PropulsionComponent.self].insert(
            PropulsionComponent(maximumThrust: 300_000, exhaustVelocity: 20_000),
            for: entity
        )
        world.components[FuelComponent.self].insert(
            FuelComponent(capacity: 2_000, remaining: remainingFuel),
            for: entity
        )
        world.components[PlayerControlComponent.self].insert(
            PlayerControlComponent(translation: SIMD2<Double>(1, -1), isFireRequested: false),
            for: entity
        )

        return (world, primary, entity)
    }
}
