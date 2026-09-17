/// Source-authored choice of which captured contacts may produce a response.
///
/// This filter is separate from physical response and damage susceptibility. A sensor may
/// receive damage when the source accepts all bodies. Detection always retains every contact.
nonisolated enum CollisionContactScope: Codable, Equatable, Sendable {
    case allBodies
    case solidBodies
}
