/// Defines either the fixed ephemeris root or one parent-relative Keplerian rail.
///
/// A complete ephemeris contains one ``root(id:state:)`` definition whose
/// identity is ``CelestialBodyID/primaryStar``. Every rail names another body
/// and a parent in the same definition.
nonisolated enum PlanarEphemerisBodyDefinition: Equatable, Sendable {
    case root(id: CelestialBodyID, state: PlanarStateVector)
    case parentRelativeRail(
        id: CelestialBodyID,
        parentID: CelestialBodyID,
        rail: PlanarKeplerianRail
    )

    var id: CelestialBodyID {
        switch self {
        case let .root(id, _), let .parentRelativeRail(id, _, _):
            id
        }
    }

    var parentID: CelestialBodyID? {
        switch self {
        case .root:
            nil
        case let .parentRelativeRail(_, parentID, _):
            parentID
        }
    }
}
