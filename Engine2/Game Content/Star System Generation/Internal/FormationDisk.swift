/// Mutable annular disk plus the immutable summary retained in generated output.
nonisolated struct FormationDisk: Sendable {
    let summary: GeneratedProtoplanetaryDisk
    var annuli: [FormationAnnulus]
    var dispersedGasMassEarth: Double
}
