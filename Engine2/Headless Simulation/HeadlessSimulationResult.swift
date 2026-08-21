import Foundation
import simd

/// Final state and timing distribution for exact one-tick Simulation requests.
///
/// The fixed-step comparison is a reporting reference. Simulation owns a
/// logical duration per tick but does not promise that wall-time execution will
/// complete within that duration on every machine or workload.
struct HeadlessSimulationResult {
    let configuration: HeadlessSimulationConfiguration
    let constructionMilliseconds: Double
    let totalMeasuredMilliseconds: Double
    let minimumTickMilliseconds: Double
    let medianTickMilliseconds: Double
    let meanTickMilliseconds: Double
    let p95TickMilliseconds: Double
    let maximumTickMilliseconds: Double
    let initialMeasuredCursor: SimulationCursor
    let finalCursor: SimulationCursor
    let firstEntityPosition: SIMD3<Double>
    let lastEntityPosition: SIMD3<Double>
    let firstEntityRotation: simd_quatf

    var ticksPerSecond: Double {
        1_000 / meanTickMilliseconds
    }

    var entityTicksPerSecond: Double {
        ticksPerSecond * Double(configuration.entityCount)
    }

    var fixedTimeStepMilliseconds: Double {
        SimulationRuntime.fixedTimeStep.milliseconds
    }

    var medianMeetsFixedTimeStepReference: Bool {
        medianTickMilliseconds <= fixedTimeStepMilliseconds
    }

    init(
        configuration: HeadlessSimulationConfiguration,
        constructionDuration: Duration,
        tickDurations: [Duration],
        initialMeasuredCursor: SimulationCursor,
        finalCursor: SimulationCursor,
        firstEntityPosition: SIMD3<Double>,
        lastEntityPosition: SIMD3<Double>,
        firstEntityRotation: simd_quatf
    ) {
        precondition(!tickDurations.isEmpty, "A headless result requires at least one measured tick.")
        precondition(
            tickDurations.count == configuration.measuredTickCount,
            "The timing sample count must match the configured measured tick count."
        )
        precondition(
            tickDurations.allSatisfy { $0 > .zero },
            "Every measured tick duration must be positive."
        )
        precondition(
            initialMeasuredCursor.sessionID == finalCursor.sessionID,
            "A headless run cannot cross Simulation sessions."
        )
        precondition(
            finalCursor.tick >= initialMeasuredCursor.tick,
            "The final headless cursor cannot precede the initial measured cursor."
        )
        precondition(
            finalCursor.tick.rawValue - initialMeasuredCursor.tick.rawValue
            == UInt64(configuration.measuredTickCount),
            "The measured cursor range must match the configured measured tick count."
        )

        let sortedMilliseconds = tickDurations
            .map(\.milliseconds)
            .sorted()
        let totalMeasuredMilliseconds = sortedMilliseconds.reduce(0, +)
        let medianIndex = sortedMilliseconds.count / 2
        let medianTickMilliseconds: Double
        if sortedMilliseconds.count.isMultiple(of: 2) {
            medianTickMilliseconds = (
                sortedMilliseconds[medianIndex - 1]
                + sortedMilliseconds[medianIndex]
            ) / 2
        } else {
            medianTickMilliseconds = sortedMilliseconds[medianIndex]
        }
        let p95Index = min(
            Int(ceil(Double(sortedMilliseconds.count) * 0.95)) - 1,
            sortedMilliseconds.count - 1
        )

        self.configuration = configuration
        self.constructionMilliseconds = constructionDuration.milliseconds
        self.totalMeasuredMilliseconds = totalMeasuredMilliseconds
        self.minimumTickMilliseconds = sortedMilliseconds[0]
        self.medianTickMilliseconds = medianTickMilliseconds
        self.meanTickMilliseconds = totalMeasuredMilliseconds / Double(sortedMilliseconds.count)
        self.p95TickMilliseconds = sortedMilliseconds[p95Index]
        self.maximumTickMilliseconds = sortedMilliseconds[sortedMilliseconds.count - 1]
        self.initialMeasuredCursor = initialMeasuredCursor
        self.finalCursor = finalCursor
        self.firstEntityPosition = firstEntityPosition
        self.lastEntityPosition = lastEntityPosition
        self.firstEntityRotation = firstEntityRotation
    }
}

extension HeadlessSimulationResult: CustomStringConvertible {
    var description: String {
        let referenceStatus = medianMeetsFixedTimeStepReference ? "WITHIN REFERENCE" : "OVER REFERENCE"
        let entityLabel = configuration.entityCount == 1 ? "entity" : "entities"

        return """
        Engine2 Headless Simulation
          workload: \(configuration.entityCount.formatted()) \(entityLabel); \
        \(configuration.warmupTickCount.formatted()) warm-up + \
        \(configuration.measuredTickCount.formatted()) measured ticks
          fixed timestep: \(decimal(fixedTimeStepMilliseconds)) ms
          runtime peers: Input Runtime absent; Render Runtime absent; UI absent; GPU work absent
          construction: \(decimal(constructionMilliseconds)) ms
          tick ms: min \(decimal(minimumTickMilliseconds)); median \(decimal(medianTickMilliseconds)); \
        mean \(decimal(meanTickMilliseconds)); p95 \(decimal(p95TickMilliseconds)); \
        max \(decimal(maximumTickMilliseconds))
          throughput: \(decimal(ticksPerSecond, digits: 2)) ticks/s; \
        \(decimal(entityTicksPerSecond, digits: 0)) entity-ticks/s
          final cursor: \(finalCursor.tick.rawValue)
          first position: \(vector(firstEntityPosition))
          last position: \(vector(lastEntityPosition))
          first rotation: \(vector(firstEntityRotation.vector))
          median fixed-step wall-time reference: \(referenceStatus)
        """
    }

    private func decimal(_ value: Double, digits: Int = 3) -> String {
        String(format: "%.\(digits)f", value)
    }

    private func vector(_ value: SIMD3<Double>) -> String {
        "(\(decimal(value.x)), \(decimal(value.y)), \(decimal(value.z)))"
    }

    private func vector(_ value: SIMD4<Float>) -> String {
        """
        (\(decimal(Double(value.x))), \(decimal(Double(value.y))), \
        \(decimal(Double(value.z))), \(decimal(Double(value.w))))
        """
    }
}
