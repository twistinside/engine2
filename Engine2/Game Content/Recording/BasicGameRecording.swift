/// Durable-file compatibility selected by the example Game Content.
///
/// The identifier covers the tick-zero world recipe, Simulation policy, entity
/// and asset vocabularies, and the packaged assets required by recorded files.
/// A breaking change to any of those inputs requires a new identifier.
nonisolated enum BasicGameRecording {
    static let contentIdentifier = RecordingContentIdentifier(
        rawValue: "engine2.basic-game.v1"
    )
}
