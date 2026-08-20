/// World-owned epoch and prediction basis shared by celestial systems.
///
/// The celestial-dynamics system owns mutation authority. Other systems read
/// the completed value after scheduling establishes a coherent commit boundary
/// with every ``COrbitalMotion`` row.
struct CelestialTimeline: PResource, Codable, Equatable, Sendable {
    private(set) var epoch: CelestialEpoch
    private(set) var predictionBasisRevision: CelestialPredictionBasisRevision

    /// Commits a nondecreasing epoch and prediction basis after orbital rows succeed.
    mutating func commit(
        epoch: CelestialEpoch,
        predictionBasisRevision: CelestialPredictionBasisRevision
    ) {
        precondition(epoch >= self.epoch, "A celestial timeline cannot move to an earlier epoch.")
        precondition(
            predictionBasisRevision >= self.predictionBasisRevision,
            "A celestial prediction-basis revision cannot decrease."
        )
        self.epoch = epoch
        self.predictionBasisRevision = predictionBasisRevision
    }
}
