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
            fixture.world.fuelComponents[fixture.entity]?.remaining
        )
        var previousSpeed = 0.0

        for _ in 0..<2 {
            fixture.world.playerControlComponents.update(for: fixture.entity) {
                $0.translation = SIMD2<Double>(1, -1)
            }
            let fuel = try #require(fixture.world.fuelComponents[fixture.entity])
            let massComponent = try #require(
                fixture.world.massComponents[fixture.entity]
            )
            let mass = massComponent.totalMass(fuel: fuel, cargo: nil)

            system.update(world: &fixture.world, deltaTime: deltaTime)

            let acceleration = try #require(
                fixture.world.motionComponents[fixture.entity]?.acceleration
            )
            #expect(
                abs(simd_length(acceleration) - maximumThrust / mass) < 1e-12
            )
            #expect(
                fixture.world.playerControlComponents[fixture.entity]?.translation
                    == .zero
            )
            #expect(
                fixture.world.orbitCircularizationAutopilotComponents[fixture.entity]
                    == .engaged(direction: .counterclockwise)
            )

            movement.update(world: &fixture.world, deltaTime: deltaTime)

            let motion = try #require(
                fixture.world.motionComponents[fixture.entity]
            )
            let speed = simd_length(motion.velocity)
            #expect(speed > previousSpeed)
            previousSpeed = speed
        }

        let expectedFuel = initialFuel
            - 2 * maximumThrust * deltaTime / exhaustVelocity
        let remainingFuel = try #require(
            fixture.world.fuelComponents[fixture.entity]?.remaining
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
            fixture.world.orbitCircularizationAutopilotComponents[fixture.entity]
                == .engaged(direction: .counterclockwise)
        )
        movement.update(world: &fixture.world, deltaTime: deltaTime)

        let terminalEstimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )
        #expect(terminalEstimate.deltaV < completionTolerance)
        let fuelAfterBurn = try #require(
            fixture.world.fuelComponents[fixture.entity]?.remaining
        )
        fixture.world.playerControlComponents.update(for: fixture.entity) {
            $0.translation = SIMD2<Double>(-1, 1)
        }

        system.update(world: &fixture.world, deltaTime: deltaTime)

        #expect(fixture.world.orbitCircularizationAutopilotComponents[fixture.entity] == .idle)
        #expect(fixture.world.playerControlComponents[fixture.entity]?.translation == .zero)
        #expect(fixture.world.motionComponents[fixture.entity]?.acceleration == .zero)
        #expect(fixture.world.fuelComponents[fixture.entity]?.remaining == fuelAfterBurn)
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
            heldFixture.world.fuelComponents[heldFixture.entity]?.remaining
        )
        let maximumTickCount = 600
        var didComplete = false

        for _ in 0..<maximumTickCount {
            heldFixture.world.playerControlComponents.update(for: heldFixture.entity) {
                $0.translation = SIMD2<Double>(1, 0)
            }
            neutralFixture.world.playerControlComponents.update(for: neutralFixture.entity) {
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
                heldFixture.world.playerControlComponents[heldFixture.entity]?.translation
                    == .zero
            )
            #expect(
                heldFixture.world.positionComponents[heldFixture.entity]
                    == neutralFixture.world.positionComponents[neutralFixture.entity]
            )
            #expect(
                heldFixture.world.motionComponents[heldFixture.entity]
                    == neutralFixture.world.motionComponents[neutralFixture.entity]
            )
            #expect(
                heldFixture.world.fuelComponents[heldFixture.entity]
                    == neutralFixture.world.fuelComponents[neutralFixture.entity]
            )
            #expect(
                heldFixture.world.orbitCircularizationAutopilotComponents[heldFixture.entity]
                    == neutralFixture.world.orbitCircularizationAutopilotComponents[neutralFixture.entity]
            )

            if heldFixture.world.orbitCircularizationAutopilotComponents[heldFixture.entity]
                == .idle {
                didComplete = true
                break
            }
        }

        let finalFuel = try #require(
            heldFixture.world.fuelComponents[heldFixture.entity]?.remaining
        )
        #expect(didComplete)
        #expect(heldFixture.world.orbitCircularizationAutopilotComponents[heldFixture.entity] == .idle)
        #expect(finalFuel < initialFuel)
    }

    @Test func insufficientFuelDisengagesAfterSuppressingTranslation() throws {
        var fixture = makeFixture(entityVelocity: .zero, remainingFuel: 1)
        var system = OrbitCircularizationAutopilotSystem(
            completionTolerance: completionTolerance
        )
        let originalMotion = try #require(fixture.world.motionComponents[fixture.entity])
        let originalFuel = try #require(fixture.world.fuelComponents[fixture.entity])
        let estimate = try #require(
            fixture.world.orbitCircularizationEstimate(for: fixture.entity)
        )
        #expect(!estimate.hasSufficientFuel)

        system.update(world: &fixture.world, deltaTime: deltaTime)

        #expect(fixture.world.orbitCircularizationAutopilotComponents[fixture.entity] == .idle)
        #expect(fixture.world.playerControlComponents[fixture.entity]?.translation == .zero)
        #expect(fixture.world.motionComponents[fixture.entity] == originalMotion)
        #expect(fixture.world.fuelComponents[fixture.entity] == originalFuel)
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
            fixture.world.motionComponents[fixture.entity]?.acceleration
        )
        #expect(acceleration.y < 0)
        #expect(
            fixture.world.orbitCircularizationAutopilotComponents[fixture.entity]
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

        world.positionComponents.insert(PositionComponent(position: .zero), for: primary)
        world.gravitySourceComponents.insert(
            GravitySourceComponent(gravitationalParameter: gravitationalParameter),
            for: primary
        )
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 100, response: .solid(restitution: 0.35)),
            for: primary
        )
        world.positionComponents.insert(
            PositionComponent(position: SIMD3<Double>(radius, 0, 0)),
            for: entity
        )
        world.motionComponents.insert(MotionComponent(velocity: entityVelocity), for: entity)
        world.gravityReceiverComponents.insert(GravityReceiverComponent(), for: entity)
        world.orbitPrimaryComponents.insert(
            OrbitPrimaryComponent(primaryEntityID: primary),
            for: entity
        )
        world.orbitCircularizationAutopilotComponents.insert(
            .engaged(direction: direction),
            for: entity
        )
        world.collisionBodyComponents.insert(
            CollisionBodyComponent(radius: 10, response: .solid(restitution: 0.35)),
            for: entity
        )
        world.massComponents.insert(MassComponent(dryMass: 10_000), for: entity)
        world.propulsionComponents.insert(
            PropulsionComponent(
                maximumThrust: maximumThrust,
                exhaustVelocity: exhaustVelocity
            ),
            for: entity
        )
        world.fuelComponents.insert(
            FuelComponent(capacity: 2_000, remaining: remainingFuel),
            for: entity
        )
        world.playerControlComponents.insert(
            PlayerControlComponent(translation: SIMD2<Double>(1, -1), isFireRequested: false),
            for: entity
        )

        return (world, entity)
    }
}
