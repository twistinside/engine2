import Testing
import simd
@testable import Engine2

struct OrbitCircularizationAutopilotSystemTests {
    private let completionTolerance = 0.5
    private let deltaTime = 1.0 / 60
    private let exhaustVelocity = 20_000.0
    private let gravitationalParameter = 4_000_000.0
    private let maximumThrust = 300_000.0
    private let radius = 2_000.0

    @Test func appliesThrustAndFuelLimitsAcrossCompleteIntervals() throws {
        var fixture = makeFixture(entityVelocity: .zero, remainingFuel: 2_000)
        var system = OrbitCircularizationAutopilotSystem(
            completionTolerance: completionTolerance
        )
        var movement = MovementSystem()
        let initialFuel = try #require(
            fixture.world.components[FuelComponent.self][fixture.entity]?.remaining
        )
        var previousSpeed = 0.0

        for _ in 0..<2 {
            fixture.world.components[PlayerControlComponent.self].update(for: fixture.entity) {
                $0.translation = SIMD2<Double>(1, -1)
            }
            let fuel = try #require(fixture.world.components[FuelComponent.self][fixture.entity])
            let massComponent = try #require(
                fixture.world.components[MassComponent.self][fixture.entity]
            )
            let mass = massComponent.totalMass(fuel: fuel, cargo: nil)

            system.update(world: &fixture.world, deltaTime: deltaTime)

            let acceleration = try #require(
                fixture.world.components[MotionComponent.self][fixture.entity]?.acceleration
            )
            #expect(
                abs(simd_length(acceleration) - maximumThrust / mass) < 1e-12
            )
            #expect(
                fixture.world.components[PlayerControlComponent.self][fixture.entity]?.translation
                    == .zero
            )
            #expect(
                fixture.world.components[OrbitCircularizationAutopilotComponent.self][fixture.entity]
                    == .engaged(direction: .counterclockwise)
            )

            movement.update(world: &fixture.world, deltaTime: deltaTime)

            let motion = try #require(
                fixture.world.components[MotionComponent.self][fixture.entity]
            )
            let speed = simd_length(motion.velocity)
            #expect(speed > previousSpeed)
            previousSpeed = speed
        }

        let expectedFuel = initialFuel
            - 2 * maximumThrust * deltaTime / exhaustVelocity
        let remainingFuel = try #require(
            fixture.world.components[FuelComponent.self][fixture.entity]?.remaining
        )
        #expect(abs(remainingFuel - expectedFuel) < 1e-12)
    }

    @Test func completesAfterAThrustLimitedBurnEntersTolerance() throws {
        let circularSpeed = sqrt(gravitationalParameter / radius)
        var fixture = makeFixture(
            entityVelocity: SIMD3<Double>(0, circularSpeed - 0.6, 0),
            remainingFuel: 2_000
        )
        var system = OrbitCircularizationAutopilotSystem(
            completionTolerance: completionTolerance
        )
        var movement = MovementSystem()
        let initialEstimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )
        #expect(initialEstimate.deltaV > completionTolerance)

        system.update(world: &fixture.world, deltaTime: deltaTime)
        #expect(
            fixture.world.components[OrbitCircularizationAutopilotComponent.self][fixture.entity]
                == .engaged(direction: .counterclockwise)
        )
        movement.update(world: &fixture.world, deltaTime: deltaTime)

        let terminalEstimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )
        #expect(terminalEstimate.deltaV < completionTolerance)
        let fuelAfterBurn = try #require(
            fixture.world.components[FuelComponent.self][fixture.entity]?.remaining
        )
        fixture.world.components[PlayerControlComponent.self].update(for: fixture.entity) {
            $0.translation = SIMD2<Double>(-1, 1)
        }

        system.update(world: &fixture.world, deltaTime: deltaTime)

        #expect(fixture.world.components[OrbitCircularizationAutopilotComponent.self][fixture.entity] == .idle)
        #expect(fixture.world.components[PlayerControlComponent.self][fixture.entity]?.translation == .zero)
        #expect(fixture.world.components[MotionComponent.self][fixture.entity]?.acceleration == .zero)
        #expect(fixture.world.components[FuelComponent.self][fixture.entity]?.remaining == fuelAfterBurn)
    }

    @Test func productionForceOrderBlocksHeldManualThrustUntilCompletion() throws {
        let circularSpeed = sqrt(gravitationalParameter / radius)
        let initialVelocity = SIMD3<Double>(0, circularSpeed - 10, 0)
        var heldFixture = makeFixture(
            entityVelocity: initialVelocity,
            remainingFuel: 2_000
        )
        var neutralFixture = makeFixture(
            entityVelocity: initialVelocity,
            remainingFuel: 2_000
        )
        var heldGravity = GravitySystem()
        var heldAutopilot = OrbitCircularizationAutopilotSystem(
            completionTolerance: completionTolerance
        )
        var heldFlightControl = FlightControlSystem(targetSpeed: 90, responseTime: 2)
        var heldMovement = MovementSystem()
        var neutralGravity = GravitySystem()
        var neutralAutopilot = OrbitCircularizationAutopilotSystem(
            completionTolerance: completionTolerance
        )
        var neutralFlightControl = FlightControlSystem(targetSpeed: 90, responseTime: 2)
        var neutralMovement = MovementSystem()
        let initialFuel = try #require(
            heldFixture.world.components[FuelComponent.self][heldFixture.entity]?.remaining
        )
        let maximumTickCount = 600
        var didComplete = false

        for _ in 0..<maximumTickCount {
            heldFixture.world.components[PlayerControlComponent.self].update(for: heldFixture.entity) {
                $0.translation = SIMD2<Double>(1, 0)
            }
            neutralFixture.world.components[PlayerControlComponent.self].update(for: neutralFixture.entity) {
                $0.translation = .zero
            }

            heldGravity.update(world: &heldFixture.world, deltaTime: deltaTime)
            heldAutopilot.update(world: &heldFixture.world, deltaTime: deltaTime)
            heldFlightControl.update(world: &heldFixture.world, deltaTime: deltaTime)
            heldMovement.update(world: &heldFixture.world, deltaTime: deltaTime)

            neutralGravity.update(world: &neutralFixture.world, deltaTime: deltaTime)
            neutralAutopilot.update(world: &neutralFixture.world, deltaTime: deltaTime)
            neutralFlightControl.update(world: &neutralFixture.world, deltaTime: deltaTime)
            neutralMovement.update(world: &neutralFixture.world, deltaTime: deltaTime)

            #expect(
                heldFixture.world.components[PlayerControlComponent.self][heldFixture.entity]?.translation
                    == .zero
            )
            #expect(
                heldFixture.world.components[PositionComponent.self][heldFixture.entity]
                    == neutralFixture.world.components[PositionComponent.self][neutralFixture.entity]
            )
            #expect(
                heldFixture.world.components[MotionComponent.self][heldFixture.entity]
                    == neutralFixture.world.components[MotionComponent.self][neutralFixture.entity]
            )
            #expect(
                heldFixture.world.components[FuelComponent.self][heldFixture.entity]
                    == neutralFixture.world.components[FuelComponent.self][neutralFixture.entity]
            )
            #expect(
                heldFixture.world.components[OrbitCircularizationAutopilotComponent.self][heldFixture.entity]
                    == neutralFixture.world.components[OrbitCircularizationAutopilotComponent.self][neutralFixture.entity]
            )

            if heldFixture.world.components[OrbitCircularizationAutopilotComponent.self][heldFixture.entity]
                == .idle {
                didComplete = true
                break
            }
        }

        let finalFuel = try #require(
            heldFixture.world.components[FuelComponent.self][heldFixture.entity]?.remaining
        )
        #expect(didComplete)
        #expect(heldFixture.world.components[OrbitCircularizationAutopilotComponent.self][heldFixture.entity] == .idle)
        #expect(finalFuel < initialFuel)
    }

    @Test func insufficientFuelDisengagesAfterSuppressingTranslation() throws {
        var fixture = makeFixture(entityVelocity: .zero, remainingFuel: 1)
        var system = OrbitCircularizationAutopilotSystem(
            completionTolerance: completionTolerance
        )
        let originalMotion = try #require(fixture.world.components[MotionComponent.self][fixture.entity])
        let originalFuel = try #require(fixture.world.components[FuelComponent.self][fixture.entity])
        let estimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )
        #expect(!estimate.hasSufficientFuel)

        system.update(world: &fixture.world, deltaTime: deltaTime)

        #expect(fixture.world.components[OrbitCircularizationAutopilotComponent.self][fixture.entity] == .idle)
        #expect(fixture.world.components[PlayerControlComponent.self][fixture.entity]?.translation == .zero)
        #expect(fixture.world.components[MotionComponent.self][fixture.entity] == originalMotion)
        #expect(fixture.world.components[FuelComponent.self][fixture.entity] == originalFuel)
    }

    @Test func burnFollowsTheLatchedDirectionWhenTheOtherTargetIsCloser() throws {
        var fixture = makeFixture(
            entityVelocity: SIMD3<Double>(0, 40, 0),
            remainingFuel: 2_000,
            direction: .clockwise
        )
        var system = OrbitCircularizationAutopilotSystem(
            completionTolerance: completionTolerance
        )

        system.update(world: &fixture.world, deltaTime: deltaTime)

        let acceleration = try #require(
            fixture.world.components[MotionComponent.self][fixture.entity]?.acceleration
        )
        #expect(acceleration.y < 0)
        #expect(
            fixture.world.components[OrbitCircularizationAutopilotComponent.self][fixture.entity]
                == .engaged(direction: .clockwise)
        )
    }

    private func makeFixture(
        entityVelocity: SIMD3<Double>,
        remainingFuel: Double,
        direction: OrbitCircularizationAutopilotComponent.Direction = .counterclockwise
    ) -> (world: World, entity: EntityID) {
        let world = World()
        let primary = EntityID(index: 0, generation: 0)
        let entity = EntityID(index: 1, generation: 0)

        world.components[PositionComponent.self].insert(PositionComponent(position: .zero), for: primary)
        world.components[GravitySourceComponent.self].insert(
            GravitySourceComponent(gravitationalParameter: gravitationalParameter),
            for: primary
        )
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 100, response: .solid(restitution: 0.35)),
            for: primary
        )
        world.components[PositionComponent.self].insert(
            PositionComponent(position: SIMD3<Double>(radius, 0, 0)),
            for: entity
        )
        world.components[MotionComponent.self].insert(MotionComponent(velocity: entityVelocity), for: entity)
        world.components[GravityReceiverComponent.self].insert(GravityReceiverComponent(), for: entity)
        world.components[OrbitPrimaryComponent.self].insert(
            OrbitPrimaryComponent(primaryEntityID: primary),
            for: entity
        )
        world.components[OrbitCircularizationAutopilotComponent.self].insert(
            .engaged(direction: direction),
            for: entity
        )
        world.components[CollisionBodyComponent.self].insert(
            CollisionBodyComponent(radius: 10, response: .solid(restitution: 0.35)),
            for: entity
        )
        world.components[MassComponent.self].insert(MassComponent(dryMass: 10_000), for: entity)
        world.components[PropulsionComponent.self].insert(
            PropulsionComponent(
                maximumThrust: maximumThrust,
                exhaustVelocity: exhaustVelocity
            ),
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

        return (world, entity)
    }
}
