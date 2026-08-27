import simd

/// One normalized scene-selection request published by an Input Runtime.
///
/// `normalizedPosition` uses bottom-left-origin unit coordinates. The aspect
/// ratio belongs to the same physical press so Simulation can reconstruct the
/// displayed projection even when the surface changes size before consumption.
nonisolated struct SelectionPress: Equatable, Sendable {
    let normalizedPosition: SIMD2<Float>
    let aspectRatio: Float

    init?(normalizedPosition: SIMD2<Float>, aspectRatio: Float) {
        guard normalizedPosition.isFinite,
              normalizedPosition.x >= 0,
              normalizedPosition.x <= 1,
              normalizedPosition.y >= 0,
              normalizedPosition.y <= 1,
              aspectRatio.isFinite,
              aspectRatio > 0 else {
            return nil
        }

        self.normalizedPosition = normalizedPosition
        self.aspectRatio = aspectRatio
    }
}
