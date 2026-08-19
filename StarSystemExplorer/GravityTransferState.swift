/// Represents the complete player-visible state of circular-reference transfer planning.
enum GravityTransferState {
    case noPlanets
    case onePlanet(GeneratedBodyID)
    case selectionIncomplete
    case ready(HohmannTransferPlan)
    case failed(String)
}
