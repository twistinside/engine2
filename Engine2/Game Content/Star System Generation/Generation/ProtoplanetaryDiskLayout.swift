/// Derived mass budgets and annular geometry for one sampled protoplanetary disk.
nonisolated struct ProtoplanetaryDiskLayout: Sendable {
    let gasMassEarth: Double
    let solidMassEarth: Double
    let innerEdgeAU: Double
    let outerEdgeAU: Double
    let snowLineAU: Double
    let radialEdges: [Double]
    let normalizedAnnulusWeights: [Double]
}
