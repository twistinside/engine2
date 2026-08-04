/// Stable schema-v1 material vocabulary recorded independently of domain coding.
nonisolated enum RenderTraceMaterialIDRecord: String, Codable, Sendable {
    case warmDielectricSmooth
    case warmDielectric
    case warmDielectricRough
    case goldMetalSmooth
    case goldMetal
    case goldMetalRough

    /// Reconstructs the Game Content material identity.
    var value: MaterialID {
        switch self {
        case .warmDielectricSmooth:
            .warmDielectricSmooth
        case .warmDielectric:
            .warmDielectric
        case .warmDielectricRough:
            .warmDielectricRough
        case .goldMetalSmooth:
            .goldMetalSmooth
        case .goldMetal:
            .goldMetal
        case .goldMetalRough:
            .goldMetalRough
        }
    }

    init(_ materialID: MaterialID) {
        switch materialID {
        case .warmDielectricSmooth:
            self = .warmDielectricSmooth
        case .warmDielectric:
            self = .warmDielectric
        case .warmDielectricRough:
            self = .warmDielectricRough
        case .goldMetalSmooth:
            self = .goldMetalSmooth
        case .goldMetal:
            self = .goldMetal
        case .goldMetalRough:
            self = .goldMetalRough
        }
    }
}
