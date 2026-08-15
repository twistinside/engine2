/// Completed gas-disk formation state handed to post-disk architecture clearing.
nonisolated struct PlanetaryFormationResult: Sendable {
    var disk: FormationDisk
    var embryos: [FormationEmbryo]
    let seededEmbryoCount: Int
    let formationMergerCount: Int
}
