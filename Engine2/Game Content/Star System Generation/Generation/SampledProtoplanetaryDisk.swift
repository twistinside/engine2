/// Seeded V1 disk priors sampled before the generator derives conserved geometry.
nonisolated struct SampledProtoplanetaryDisk: Sendable {
    let diskMassRatio: Double
    let lifetimeMegayears: Double
    let characteristicRadiusAU: Double
    let surfaceDensityExponent: Double
    let innerIronFraction: Double
    let innerWaterFraction: Double
    let solidFraction: Double
}
