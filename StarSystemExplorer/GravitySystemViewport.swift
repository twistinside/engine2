import CoreGraphics

/// Maps physical planar meters into a centered, top-down canvas viewport.
///
/// The viewport preserves one physical linear scale on both axes. Positive planar
/// Y points toward the top of the canvas, matching the explorer's top-down view.
nonisolated struct GravitySystemViewport: Sendable {
    let size: CGSize
    let padding: CGFloat
    let extentMeters: Double

    var center: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    var pointsPerMeter: CGFloat {
        let drawableWidth = max(1, size.width - padding * 2)
        let drawableHeight = max(1, size.height - padding * 2)
        return min(drawableWidth, drawableHeight) / CGFloat(2 * extentMeters)
    }

    init(size: CGSize, padding: CGFloat, extentMeters: Double) {
        precondition(
            padding.isFinite && padding >= 0,
            "Viewport padding must be finite and nonnegative."
        )
        precondition(
            extentMeters.isFinite && extentMeters > 0,
            "Viewport extent must be finite and positive."
        )
        self.size = size
        self.padding = padding
        self.extentMeters = extentMeters
    }

    func point(for position: PlanarPosition) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(position.meters.x) * pointsPerMeter,
            y: center.y - CGFloat(position.meters.y) * pointsPerMeter
        )
    }
}
