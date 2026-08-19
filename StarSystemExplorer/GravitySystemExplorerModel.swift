import Observation
import simd

/// Projects one generated system into gravity rails and owns the explorer's deterministic time and transfer state.
@Observable
final class GravitySystemExplorerModel {
    let sourceSystem: GeneratedStarSystem

    private(set) var projectionState = GravitySystemProjectionState.failed("The gravity projection is not available.")
    private(set) var transferState = GravityTransferState.selectionIncomplete
    private(set) var maximumElapsedSeconds = AstronomicalDuration.year.seconds
    private(set) var selectedSourceID: GeneratedBodyID?
    private(set) var selectedDestinationID: GeneratedBodyID?
    private(set) var planetRailPositions: [GeneratedBodyID: [PlanarPosition]] = [:]
    private(set) var moonRelativeRailPositions: [GeneratedBodyID: [PlanarPosition]] = [:]
    private(set) var transferPositions: [PlanarPosition] = []

    /// Stable physical half-extent used by every displayed epoch.
    private(set) var diagramExtentMeters = 1.0

    private(set) var displayFrame = GravitySystemDisplayFrame(
        epoch: .zero,
        bodyStates: [],
        selectedGravityAccelerationMetersPerSecondSquared: nil,
        transferVehicleState: nil
    )

    private let propagationKernel = PlanarKeplerPropagationKernel()
    private let transferVehicleProjection = GravityTransferVehicleProjection()
    private var ephemeris: GravitySystemEphemeris?
    private var gravityField: PlanarGravityField?
    private var transferPlanner: HohmannTransferPlanner?
    private var baseMaximumElapsedSeconds = AstronomicalDuration.year.seconds

    var elapsedSeconds: Double {
        displayFrame.elapsedSeconds
    }

    var bodyStates: [GravityBodyState] {
        displayFrame.bodyStates
    }

    var selectedGravityAccelerationMetersPerSecondSquared: Double? {
        displayFrame.selectedGravityAccelerationMetersPerSecondSquared
    }

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

    var transferVehicleState: GravityTransferVehicleState? {
        displayFrame.transferVehicleState
    }

    var currentEpoch: CelestialEpoch {
        displayFrame.epoch
    }

    init(system: GeneratedStarSystem) {
        sourceSystem = system
        configureGravityProjection()
    }

    func setElapsedSeconds(_ elapsedSeconds: Double) {
        let clampedElapsedSeconds = min(max(elapsedSeconds, 0), maximumElapsedSeconds)
        updateEpochProjection(
            at: CelestialEpoch(secondsSinceReferenceEpoch: clampedElapsedSeconds)
        )
    }

    func selectSource(_ bodyID: GeneratedBodyID) {
        guard sourceSystem.planets.contains(where: { $0.id == bodyID }) else {
            return
        }
        selectedSourceID = bodyID
        if selectedDestinationID == bodyID {
            selectedDestinationID = sourceSystem.planets.first { $0.id != bodyID }?.id
        }
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
        displayFrame.state(for: bodyID)
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
            configureDiagramExtent(in: gravitySystem)
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

    private func configureDiagramExtent(in gravitySystem: GeneratedGravitySystem) {
        let maximumPlanetCoordinateByID = planetRailPositions.mapValues { positions in
            positions.reduce(0.0) { currentMaximum, position in
                max(currentMaximum, abs(position.meters.x), abs(position.meters.y))
            }
        }
        var maximumCoordinate = maximumPlanetCoordinateByID.values.max() ?? 0
        for body in gravitySystem.bodies {
            guard let parentID = body.parentID,
                  let parentMaximum = maximumPlanetCoordinateByID[parentID] else {
                continue
            }
            let moonApoapsis = body.rail.semiMajorAxis.meters
                * (1 + body.rail.eccentricity.rawValue)
            maximumCoordinate = max(maximumCoordinate, parentMaximum + moonApoapsis)
        }

        let fallback = max(
            sourceSystem.star.radius.meters * 12,
            sourceSystem.protoplanetaryDisk.outerEdge.meters
        )
        guard maximumCoordinate > 0 else {
            diagramExtentMeters = max(fallback, 1)
            return
        }
        diagramExtentMeters = max(
            maximumCoordinate * 1.12,
            sourceSystem.star.radius.meters * 12,
            1
        )
    }

    private func updateEpochProjection(at epoch: CelestialEpoch? = nil) {
        let epoch = epoch ?? currentEpoch
        guard let ephemeris else {
            displayFrame = GravitySystemDisplayFrame(
                epoch: epoch,
                bodyStates: [],
                selectedGravityAccelerationMetersPerSecondSquared: nil,
                transferVehicleState: nil
            )
            return
        }
        let bodyStates = ephemeris.states(at: epoch)
        displayFrame = GravitySystemDisplayFrame(
            epoch: epoch,
            bodyStates: bodyStates,
            selectedGravityAccelerationMetersPerSecondSquared:
                selectedGravityAcceleration(in: bodyStates),
            transferVehicleState: transferPlan.map {
                transferVehicleProjection.state(for: $0, at: epoch)
            }
        )
    }

    private func updateTransferPlan() {
        defer {
            updateEpochProjection()
        }
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

    private func selectedGravityAcceleration(
        in bodyStates: [GravityBodyState]
    ) -> Double? {
        guard let selectedSourceID,
              let sourceState = bodyStates.first(where: { $0.body.id == selectedSourceID })?.state,
              let gravityField,
              let acceleration = try? gravityField.acceleration(
                  at: sourceState.position,
                  fromExactStates: bodyStates,
                  excluding: selectedSourceID
              ) else {
            return nil
        }
        return simd_length(
            acceleration.metersPerSecondSquared
        )
    }
}
