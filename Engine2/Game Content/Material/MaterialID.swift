/// Exhaustive Game Content identity for authored surface materials.
///
/// Simulation carries this backend-neutral value as authoritative presentation
/// intent, while Render resolves it through content supplied by the App. The
/// identity never exposes material factors, GPU storage, or Metal resources.
/// `CaseIterable` lets Render validate that its catalog covers the complete
/// Game Content vocabulary before drawing begins.
nonisolated enum MaterialID: CaseIterable, Codable, Hashable, Sendable {
    case warmDielectric
    case goldMetal
}
