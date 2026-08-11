/// Nonnegative pressure stored in pascals.
nonisolated struct SurfacePressure: Codable, Equatable, Hashable, Sendable {
    static let vacuum = SurfacePressure(pascals: 0)
    static let bar = SurfacePressure(pascals: 100_000.0)

    let pascals: Double

    var bars: Double {
        pascals / Self.bar.pascals
    }

    init(pascals: Double) {
        precondition(
            pascals.isFinite && pascals >= 0,
            "Surface pressure must be finite and nonnegative."
        )
        self.pascals = pascals
    }

    init(bars: Double) {
        self.init(pascals: bars * Self.bar.pascals)
    }
}
