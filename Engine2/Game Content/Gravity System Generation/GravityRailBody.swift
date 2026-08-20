/// One generated massive body following a parent-relative planar Keplerian rail.
///
/// A `nil` parent identifies a planet orbiting the generated star. A moon names
/// its generated planet parent. The star remains the root stored directly on
/// ``GeneratedGravitySystem`` rather than receiving an invented body identity.
nonisolated struct GravityRailBody: Codable, Equatable, Sendable {
    let id: GeneratedBodyID
    let parentID: GeneratedBodyID?
    let mass: AstronomicalMass
    let radius: AstronomicalDistance
    let rail: PlanarKeplerianRail
}
