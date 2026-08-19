import Testing
import simd

@testable import StarSystemExplorer

@MainActor
struct GravitySystemExplorerModelTests {
    private let generator = StarSystemGenerator(policy: .coreAccretionLiteV1)

    @Test func manyBodySystemProjectsRailsAndKeepsTheTransferStableWhileScrubbing() throws {
        let sourceSystem = try generator.generate(seed: StarSystemSeed(rawValue: 1))
        let model = GravitySystemExplorerModel(system: sourceSystem)
        let gravitySystem = try #require(model.gravitySystem)
        let initialPlan = try #require(model.transferPlan)

        #expect(gravitySystem.bodies.count == sourceSystem.planets.reduce(0) { $0 + 1 + $1.moons.count })
        #expect(model.bodyStates.count == gravitySystem.bodies.count)
        #expect(model.planetRailPositions.count == sourceSystem.planets.count)
        #expect(!model.transferPositions.isEmpty)

        model.setElapsedSeconds(initialPlan.departureEpoch.secondsSinceReferenceEpoch)

        #expect(model.currentEpoch == initialPlan.departureEpoch)
        #expect(model.transferPlan == initialPlan)
        #expect(model.bodyStates.count == gravitySystem.bodies.count)
    }

    @Test func transferSelectionCanReverseTheReferenceRoute() throws {
        let sourceSystem = try generator.generate(seed: StarSystemSeed(rawValue: 1))
        let model = GravitySystemExplorerModel(system: sourceSystem)
        let initialPlan = try #require(model.transferPlan)

        model.swapSelectedPlanets()

        let reversedPlan = try #require(model.transferPlan)
        #expect(reversedPlan.sourceBodyID == initialPlan.destinationBodyID)
        #expect(reversedPlan.destinationBodyID == initialPlan.sourceBodyID)
        #expect(reversedPlan.transferRail != initialPlan.transferRail)
    }

    @Test func transferVehicleClampsToEndpointsAndUsesTheKernelDuringFlight() throws {
        let sourceSystem = try generator.generate(seed: StarSystemSeed(rawValue: 1))
        let model = GravitySystemExplorerModel(system: sourceSystem)
        let plan = try #require(model.transferPlan)
        let projection = GravityTransferVehicleProjection()
        let propagationKernel = PlanarKeplerPropagationKernel()
        let departurePosition = propagationKernel.state(
            on: plan.transferRail,
            at: plan.departureEpoch
        ).position
        let arrivalPosition = propagationKernel.state(
            on: plan.transferRail,
            at: plan.arrivalEpoch
        ).position

        #expect(plan.departureEpoch > .zero)
        let beforeDeparture = projection.state(for: plan, at: .zero)
        #expect(beforeDeparture.status == .awaitingDeparture)
        #expect(beforeDeparture.position == departurePosition)
        #expect(model.transferVehicleState == beforeDeparture)

        model.setElapsedSeconds(plan.departureEpoch.secondsSinceReferenceEpoch)
        let atDeparture = try #require(model.transferVehicleState)
        #expect(atDeparture.status == .inFlight)
        #expect(atDeparture.position == departurePosition)

        let middleEpoch = CelestialEpoch(
            secondsSinceReferenceEpoch: (
                plan.departureEpoch.secondsSinceReferenceEpoch
                    + plan.arrivalEpoch.secondsSinceReferenceEpoch
            ) / 2
        )
        model.setElapsedSeconds(middleEpoch.secondsSinceReferenceEpoch)
        let inFlight = try #require(model.transferVehicleState)
        #expect(inFlight.status == .inFlight)
        #expect(
            inFlight.position == propagationKernel.state(
                on: plan.transferRail,
                at: middleEpoch
            ).position
        )

        model.setElapsedSeconds(plan.arrivalEpoch.secondsSinceReferenceEpoch)
        let atArrival = try #require(model.transferVehicleState)
        #expect(atArrival.status == .atArrivalReference)
        #expect(atArrival.position == arrivalPosition)

        let afterArrival = projection.state(
            for: plan,
            at: plan.arrivalEpoch.advanced(by: AstronomicalDuration(seconds: 1))
        )
        #expect(afterArrival.status == .atArrivalReference)
        #expect(afterArrival.position == arrivalPosition)
    }

    @Test func validEmptyAndSinglePlanetSystemsExposeTypedTransferStates() throws {
        let emptySystem = try generator.generate(seed: StarSystemSeed(rawValue: 43))
        let emptyModel = GravitySystemExplorerModel(system: emptySystem)
        let singleSystem = try generator.generate(seed: StarSystemSeed(rawValue: 67))
        let singleModel = GravitySystemExplorerModel(system: singleSystem)

        guard case .noPlanets = emptyModel.transferState else {
            Issue.record("Seed 43 should expose the typed no-planets transfer state.")
            return
        }
        guard case .onePlanet(let bodyID) = singleModel.transferState else {
            Issue.record("Seed 67 should expose the typed one-planet transfer state.")
            return
        }
        #expect(emptyModel.gravitySystem?.bodies.isEmpty == true)
        #expect(emptyModel.transferVehicleState == nil)
        #expect(bodyID == singleSystem.planets.first?.id)
        #expect(singleModel.transferVehicleState == nil)
    }

    @Test func epochFramesMatchDynamicsAndKeepStaticGeometryUnchanged() throws {
        let sourceSystem = try generator.generate(seed: StarSystemSeed(rawValue: 67))
        let model = GravitySystemExplorerModel(system: sourceSystem)
        let gravitySystem = try #require(model.gravitySystem)
        let ephemeris = try GravitySystemEphemeris(system: gravitySystem)
        let gravityField = PlanarGravityField(ephemeris: ephemeris)
        let planetRails = model.planetRailPositions
        let moonRails = model.moonRelativeRailPositions
        let extentMeters = model.diagramExtentMeters
        let selectedSourceID = try #require(model.selectedSourceID)

        for elapsedSeconds in [0.0, 123_456, model.maximumElapsedSeconds] {
            model.setElapsedSeconds(elapsedSeconds)

            let expectedStates = ephemeris.states(at: model.currentEpoch)
            let sourceState = try #require(
                expectedStates.first(where: { $0.body.id == selectedSourceID })
            )
            let expectedAcceleration = try gravityField.acceleration(
                at: sourceState.state.position,
                fromExactStates: expectedStates,
                excluding: selectedSourceID
            )

            #expect(model.bodyStates == expectedStates)
            #expect(
                model.selectedGravityAccelerationMetersPerSecondSquared
                    == simd_length(expectedAcceleration.metersPerSecondSquared)
            )
            #expect(model.planetRailPositions == planetRails)
            #expect(model.moonRelativeRailPositions == moonRails)
            #expect(model.diagramExtentMeters == extentMeters)
        }
    }
}
