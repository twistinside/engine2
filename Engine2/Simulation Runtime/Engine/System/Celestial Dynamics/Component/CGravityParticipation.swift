/// Independent source and receiver role used by celestial gravity evaluation.
///
/// Keeping this role separate from ``CMassiveBody`` supports test particles,
/// disabled sources, and source-only ephemeris bodies without changing their
/// physical mass or radius.
struct CGravityParticipation: PComponent, Sendable {
    var participation: GravityParticipation
}
