import simd
import Testing
@testable import Engine2

struct SolarSystemGravitySoakTests {
    private static let gravitationalConstant = 6.67430e-11
    private static let simulatedHourSeconds = 3_600.0
    private static let acceleratedSoakStepCount = 108_000

    @Test func acceleratedStepSoakKeepsEveryPlanetBound() async throws {
        var world = SolarSystemWorldBuilder().buildWorld()
        let initialRadii = planetRadii(in: world)
        let initialEnergy = totalEnergy(in: world)
        let initialAngularMomentum = totalAngularMomentum(in: world)
        let gravity = SGravity()
        var movement = SMovement()
        var maximumRelativeEnergyDrift = 0.0
        var maximumRelativeAngularMomentumDrift = 0.0

        for completedStep in 1...Self.acceleratedSoakStepCount {
            try gravity.accumulateGravity(in: world)
            movement.update(
                world: &world,
                deltaTime: Self.simulatedHourSeconds
            )

            if completedStep.isMultiple(of: 168) || completedStep == Self.acceleratedSoakStepCount {
                guard statesRemainFiniteAndBound(
                    in: world,
                    initialRadii: initialRadii
                ) else {
                    Issue.record(
                        "Solar System state left its admitted envelope after step \(completedStep)."
                    )
                    return
                }

                let sampledEnergy = totalEnergy(in: world)
                let sampledAngularMomentum = totalAngularMomentum(in: world)
                maximumRelativeEnergyDrift = max(
                    maximumRelativeEnergyDrift,
                    abs((sampledEnergy - initialEnergy) / initialEnergy)
                )
                maximumRelativeAngularMomentumDrift = max(
                    maximumRelativeAngularMomentumDrift,
                    simd_length(sampledAngularMomentum - initialAngularMomentum)
                        / simd_length(initialAngularMomentum)
                )
                await Task.yield()
            }
        }

        #expect(maximumRelativeEnergyDrift < 1e-5)
        #expect(maximumRelativeAngularMomentumDrift < 1e-10)
    }

    @Test func oneHourStepConvergesAgainstHalfHourReference() async throws {
        let twoHourPositions = try await positionsAfterOneYear(
            stepSeconds: 7_200
        )
        let oneHourPositions = try await positionsAfterOneYear(
            stepSeconds: 3_600
        )
        let halfHourPositions = try await positionsAfterOneYear(
            stepSeconds: 1_800
        )
        let twoToOneHourDifference = aggregateDifference(
            between: twoHourPositions,
            and: oneHourPositions
        )
        let oneToHalfHourDifference = aggregateDifference(
            between: oneHourPositions,
            and: halfHourPositions
        )

        #expect(oneToHalfHourDifference < twoToOneHourDifference * 0.6)
    }
}

private extension SolarSystemGravitySoakTests {
    func positionsAfterOneYear(
        stepSeconds: Double
    ) async throws -> [SIMD3<Double>] {
        var world = SolarSystemWorldBuilder().buildWorld()
        let gravity = SGravity()
        var movement = SMovement()
        let stepCount = Int((365 * 24 * 3_600) / stepSeconds)

        for completedStep in 1...stepCount {
            try gravity.accumulateGravity(in: world)
            movement.update(world: &world, deltaTime: stepSeconds)
            if completedStep.isMultiple(of: 168) {
                await Task.yield()
            }
        }

        return world.positionComponents.dense.map(\.position)
    }

    func aggregateDifference(
        between first: [SIMD3<Double>],
        and second: [SIMD3<Double>]
    ) -> Double {
        zip(first, second).reduce(0) { difference, positions in
            difference + simd_distance(positions.0, positions.1)
        }
    }

    func planetRadii(in world: World) -> [Double] {
        let entities = world.massiveBodyComponents.entities
        guard let sun = entities.first,
              let sunPosition = world.positionComponents[sun]?.position else {
            preconditionFailure("The Solar System fixture must retain its Sun position.")
        }

        return entities.dropFirst().map { entity in
            guard let position = world.positionComponents[entity]?.position else {
                preconditionFailure("Every Solar System planet must retain its position.")
            }
            return simd_distance(position, sunPosition)
        }
    }

    func statesRemainFiniteAndBound(
        in world: World,
        initialRadii: [Double]
    ) -> Bool {
        let entities = world.massiveBodyComponents.entities
        guard let sun = entities.first,
              let sunPosition = world.positionComponents[sun]?.position,
              let sunMotion = world.motionComponents[sun],
              let sunMass = world.massiveBodyComponents[sun]?.mass.kilograms,
              sunPosition.isFinite,
              sunMotion.velocity.isFinite else {
            return false
        }

        for (planetOffset, planet) in entities.dropFirst().enumerated() {
            guard let position = world.positionComponents[planet]?.position,
                  let motion = world.motionComponents[planet],
                  let mass = world.massiveBodyComponents[planet]?.mass.kilograms,
                  position.isFinite,
                  motion.velocity.isFinite else {
                return false
            }
            let relativePosition = position - sunPosition
            let relativeVelocity = motion.velocity - sunMotion.velocity
            let radius = simd_length(relativePosition)
            let radiusRatio = radius / initialRadii[planetOffset]
            let gravitationalParameter = Self.gravitationalConstant
                * (sunMass + mass)
            let specificOrbitalEnergy = 0.5
                * simd_length_squared(relativeVelocity)
                - gravitationalParameter / radius

            guard radius.isFinite,
                  radiusRatio > 0.5,
                  radiusRatio < 1.5,
                  specificOrbitalEnergy.isFinite,
                  specificOrbitalEnergy < 0 else {
                return false
            }
        }

        return true
    }

    func totalEnergy(in world: World) -> Double {
        let entities = world.massiveBodyComponents.entities
        var energy = 0.0

        for entity in entities {
            guard let mass = world.massiveBodyComponents[entity]?.mass.kilograms,
                  let velocity = world.motionComponents[entity]?.velocity else {
                preconditionFailure("Every Solar System body must retain mass and motion.")
            }
            energy += 0.5 * mass * simd_length_squared(velocity)
        }

        for firstOffset in entities.indices {
            let firstEntity = entities[firstOffset]
            guard let firstMass = world.massiveBodyComponents[firstEntity]?.mass.kilograms,
                  let firstPosition = world.positionComponents[firstEntity]?.position else {
                preconditionFailure("Every Solar System gravity source must retain physical state.")
            }

            for secondOffset in entities.index(after: firstOffset)..<entities.endIndex {
                let secondEntity = entities[secondOffset]
                guard let secondMass = world.massiveBodyComponents[secondEntity]?.mass.kilograms,
                      let secondPosition = world.positionComponents[secondEntity]?.position else {
                    preconditionFailure("Every Solar System gravity source must retain physical state.")
                }
                energy -= Self.gravitationalConstant
                    * firstMass
                    * secondMass
                    / simd_distance(firstPosition, secondPosition)
            }
        }

        return energy
    }

    func totalAngularMomentum(in world: World) -> SIMD3<Double> {
        world.massiveBodyComponents.entities.reduce(.zero) { angularMomentum, entity in
            guard let mass = world.massiveBodyComponents[entity]?.mass.kilograms,
                  let position = world.positionComponents[entity]?.position,
                  let velocity = world.motionComponents[entity]?.velocity else {
                preconditionFailure("Every Solar System body must retain physical motion state.")
            }
            return angularMomentum + mass * simd_cross(position, velocity)
        }
    }
}
