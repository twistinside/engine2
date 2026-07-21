/// Closed startup stages used to locate preserved Render construction errors.
enum RenderResourceConstructionStage: String, Codable, CaseIterable, Sendable {
    case catalogValidation
    case commandQueue
    case compiler
    case residency
    case frameResources
    case shaderLibrary
    case pipeline
    case fixedFunctionState
    case argumentTables
    case models
}
