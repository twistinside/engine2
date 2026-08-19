import Observation
import simd

/// Projects one generated system into gravity rails and owns the explorer's deterministic time and transfer state.
@Observable
final class GravitySystemExplorerModel {
    let sourceSystem: GeneratedStarSystem

    private(set) var projectionState = GravitySystemProjectionState.failed("The gravity projection is not available.")
    private(set) var transferState = GravityTransferState.selectionIncomplete
    private(set) var elapsedSeconds = 0.0
    private(set) var maximumElapsedSeconds = AstronomicalDuration.year.seconds
    private(set) var selectedSourceID: GeneratedBodyID?
    private(set) var selectedDestinationID: GeneratedBodyID?
    private(set) var bodyStates: [GravityBodyState] = []
    private(set) var planetRailPositions: [GeneratedBodyID: [PlanarPosition]] = [:]
    private(set) var moonRailPositions: [GeneratedBodyID: [PlanarPosition]] = [:]
    private(set) var transferPositions: [PlanarPosition] = []
    private(set) var selectedGravityAccelerationMetersPerSecondSquared: Double?

    private let propagationKernel = PlanarKeplerPropagationKernel()
    private var ephemeris: GravitySystemEphemeris?
    private var gravityField: PlanarGravityField?
    private var transferPlanner: HohmannTransferPlanner?
    private var moonRelativeRailPositions: [GeneratedBodyID: [PlanarPosition]] = [:]
    private var baseMaximumElapsedSeconds = AstronomicalDuration.year.seconds

    var gravitySystem: GeneratedGravitySystem? {
        switch projectionState {
        case .ready(let system): system
        case .failed: nil
        }
    }

    var transferPlan: HohmannTransferPlan? {
        switch transferState {
        case .ready(let plan): plan
        case .noPlanets, .onePlanet, .selectionIncomplete, .failed: nil
        }
    }

    var currentEpoch: CelestialEpoch {
        CelestialEpoch(secondsSinceReferenceEpoch: elapsedSeconds)
    }

    init(system: GeneratedStarSystem) {
        sourceSystem = system
        configureGravityProjection()
    }

    func setElapsedSeconds(_ elapsedSeconds: Double) {
        self.elapsedSeconds = min(max(elapsedSeconds, 0), maximumElapsedSeconds)
        updateEpochProjection()
    }

    func selectSource(_ bodyID: GeneratedBodyID) {
        guard sourceSystem.planets.contains(where: { $0.id == bodyID }) else {
            return
        }
        selectedSourceID = bodyID
        if selectedDestinationID == bodyID {
            selectedDestinationID = sourceSystem.planets.first { $0.id != bodyID }?.id
        }
        updateSelectedGravityAcceleration()
        updateTransferPlan()
    }

    func selectDestination(_ bodyID: GeneratedBodyID) {
        guard bodyID != selectedSourceID,
              sourceSystem.planets.contains(where: { $0.id == bodyID }) else {
            return
        }
        selectedDestinationID = bodyID
        updateTransferPlan()
    }

    func swapSelectedPlanets() {
        guard let selectedSourceID, let selectedDestinationID else {
            return
        }
        self.selectedSourceID = selectedDestinationID
        self.selectedDestinationID = selectedSourceID
        updateSelectedGravityAcceleration()
        updateTransferPlan()
    }

    func planetLabel(for bodyID: GeneratedBodyID) -> String {
        guard let index = sourceSystem.planets.firstIndex(where: { $0.id == bodyID }) else {
            return "Planet #\(bodyID.rawValue)"
        }
        return "Planet \(index + 1)"
    }

    func moonLabel(for bodyID: GeneratedBodyID) -> String {
        guard let parentID = bodyID.parentPlanetID,
              let planetIndex = sourceSystem.planets.firstIndex(where: { $0.id == parentID }),
              let moonIndex = sourceSystem.planets[planetIndex].moons.firstIndex(where: { $0.id == bodyID }) else {
            return "Moon #\(bodyID.rawValue)"
        }
        return "P\(planetIndex + 1) moon \(moonIndex + 1)"
    }

    func state(for bodyID: GeneratedBodyID) -> PlanarStateVector? {
        bodyStates.first { $0.body.id == bodyID }?.state
    }

    private func configureGravityProjection() {
        do {
            let gravitySystem = try GravitySystemGenerator(modelVersion: .planarKeplerV1).generate(from: sourceSystem)
            let ephemeris = try GravitySystemEphemeris(system: gravitySystem)
            let transferPlanner = try HohmannTransferPlanner(system: gravitySystem)
            projectionState = .ready(gravitySystem)
            self.ephemeris = ephemeris
            gravityField = PlanarGravityField(ephemeris: ephemeris)
            self.transferPlanner = transferPlanner
            configureEpochRange(for: gravitySystem)
            configureDefaultPlanetPair()
            sampleCompleteRails(in: gravitySystem)
            updateEpochProjection()
            updateTransferPlan()
        } catch {
            let message = "The generated system could not be projected into gravity rails. \(error)"
            projectionState = .failed(message)
            transferState = .failed(message)
        }
    }

    private func configureEpochRange(for gravitySystem: GeneratedGravitySystem) {
        let planetIDs = Set(sourceSystem.planets.map(\.id))
        let longestPlanetPeriod = gravitySystem.bodies
            .filter { planetIDs.contains($0.id) }
            .map(\.rail.orbitalPeriod.seconds)
            .max() ?? AstronomicalDuration.year.seconds
        baseMaximumElapsedSeconds = max(86_400, longestPlanetPeriod)
        maximumElapsedSeconds = baseMaximumElapsedSeconds
    }

    private func configureDefaultPlanetPair() {
        selectedSourceID = sourceSystem.planets.first?.id
        selectedDestinationID = sourceSystem.planets.dropFirst().first?.id
    }

    private func sampleCompleteRails(in gravitySystem: GeneratedGravitySystem) {
        let planetIDs = Set(sourceSystem.planets.map(\.id))
        for body in gravitySystem.bodies {
            let samples = propagationKernel.samples(
                on: body.rail,
                from: body.rail.epoch,
                through: body.rail.epoch.advanced(by: body.rail.orbitalPeriod),
                sampleCount: planetIDs.contains(body.id) ? 181 : 97
            )
            let positions = samples.map(\.state.position)
            if planetIDs.contains(body.id) {
                planetRailPositions[body.id] = positions
            } else {
                moonRelativeRailPositions[body.id] = positions
            }
        }
    }

    private func updateEpochProjection() {
        guard let ephemeris else {
            bodyStates = []
            moonRailPositions = [:]
            return
        }
        bodyStates = ephemeris.states(at: currentEpoch)
        moonRailPositions = moonRelativeRailPositions.reduce(into: [:]) { absoluteRails, entry in
            guard let moon = ephemeris.body(for: entry.key),
                  let parentID = moon.parentID,
                  let parentState = ephemeris.state(for: parentID, at: currentEpoch) else {
                return
            }
            absoluteRails[entry.key] = entry.value.map { relativePosition in
                parentState.position.adding(relativePosition)
            }
        }
        updateSelectedGravityAcceleration()
    }

    private func updateTransferPlan() {
        transferPositions = []
        maximumElapsedSeconds = max(baseMaximumElapsedSeconds, elapsedSeconds)

        switch sourceSystem.planets.count {
        case 0:
            transferState = .noPlanets
            return
        case 1:
            transferState = .onePlanet(sourceSystem.planets[0].id)
            return
        default:
            break
        }

        guard let transferPlanner,
              let gravitySystem,
              let selectedSourceID,
              let selectedDestinationID else {
            transferState = .selectionIncomplete
            return
        }

        do {
            let plan = try transferPlanner.plan(
                from: selectedSourceID,
                to: selectedDestinationID,
                noEarlierThan: gravitySystem.epoch
            )
            transferState = .ready(plan)
            transferPositions = propagationKernel.samples(
                on: plan.transferRail,
                from: plan.departureEpoch,
                through: plan.arrivalEpoch,
                sampleCount: 181
            )
            .map(\.state.position)
            maximumElapsedSeconds = max(
                baseMaximumElapsedSeconds,
                elapsedSeconds,
                plan.arrivalEpoch.secondsSinceReferenceEpoch
            )
        } catch {
            transferState = .failed("The selected circular-reference transfer could not be planned. \(error)")
        }
    }

    private func updateSelectedGravityAcceleration() {
        guard let selectedSourceID,
              let sourceState = state(for: selectedSourceID),
              let gravityField,
              let acceleration = try? gravityField.acceleration(
                  at: sourceState.position,
                  epoch: currentEpoch,
                  excluding: selectedSourceID
              ) else {
            selectedGravityAccelerationMetersPerSecondSquared = nil
            return
        }
        selectedGravityAccelerationMetersPerSecondSquared = simd_length(
            acceleration.metersPerSecondSquared
        )
    }
}
