/// Validated finite workload selected by the headless Simulation host.
///
/// Entity construction and warm-up remain outside the measured interval.
/// Every measured sample advances exactly one complete Simulation Runtime tick.
struct HeadlessSimulationConfiguration {
    static let defaultEntityCount = 100_000
    static let defaultWarmupTickCount = 10
    static let defaultMeasuredTickCount = 60

    let entityCount: Int
    let warmupTickCount: Int
    let measuredTickCount: Int

    /// Constructs a workload from explicit positive counts.
    init(
        entityCount: Int,
        warmupTickCount: Int,
        measuredTickCount: Int
    ) throws(HeadlessSimulationError) {
        guard entityCount > 0 else {
            throw .invalidConfiguration("Entity count must be positive.")
        }
        guard warmupTickCount > 0 else {
            throw .invalidConfiguration("Warm-up tick count must be positive.")
        }
        guard measuredTickCount > 0 else {
            throw .invalidConfiguration("Measured tick count must be positive.")
        }

        self.entityCount = entityCount
        self.warmupTickCount = warmupTickCount
        self.measuredTickCount = measuredTickCount
    }

    /// Reads optional process overrides while retaining deterministic defaults.
    init(environment: [String: String]) throws(HeadlessSimulationError) {
        try self.init(
            entityCount: Self.positiveInteger(
                for: .entityCount,
                in: environment,
                defaultValue: Self.defaultEntityCount
            ),
            warmupTickCount: Self.positiveInteger(
                for: .warmupTickCount,
                in: environment,
                defaultValue: Self.defaultWarmupTickCount
            ),
            measuredTickCount: Self.positiveInteger(
                for: .measuredTickCount,
                in: environment,
                defaultValue: Self.defaultMeasuredTickCount
            )
        )
    }

    private static func positiveInteger(
        for key: HeadlessSimulationEnvironmentKey,
        in environment: [String: String],
        defaultValue: Int
    ) throws(HeadlessSimulationError) -> Int {
        guard let rawValue = environment[key.rawValue] else {
            return defaultValue
        }
        guard let value = Int(rawValue), value > 0 else {
            throw .invalidEnvironmentValue(key: key, value: rawValue)
        }
        return value
    }
}
