/// Versioned compatibility metadata emitted before a diagnostic sample stream.
struct DiagnosticsManifest: Codable, Equatable, Sendable {
    let schemaVersion: UInt
    let sessionID: DiagnosticsSessionID
    let scenarioID: DiagnosticsScenarioID
    let scenarioSchemaVersion: UInt
    let buildConfiguration: DiagnosticsBuildConfiguration
    let randomSeed: UInt64
    let fixedStepNanoseconds: UInt64
    let warmUpNanoseconds: UInt64
    let measurementNanoseconds: UInt64

    init(
        schemaVersion: UInt = DiagnosticsArtifactSchema.currentVersion,
        sessionID: DiagnosticsSessionID,
        scenarioID: DiagnosticsScenarioID,
        scenarioSchemaVersion: UInt = 1,
        buildConfiguration: DiagnosticsBuildConfiguration,
        randomSeed: UInt64,
        fixedStepNanoseconds: UInt64,
        warmUpNanoseconds: UInt64,
        measurementNanoseconds: UInt64
    ) {
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.scenarioID = scenarioID
        self.scenarioSchemaVersion = scenarioSchemaVersion
        self.buildConfiguration = buildConfiguration
        self.randomSeed = randomSeed
        self.fixedStepNanoseconds = fixedStepNanoseconds
        self.warmUpNanoseconds = warmUpNanoseconds
        self.measurementNanoseconds = measurementNanoseconds
    }
}
