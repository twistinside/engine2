import CoreGraphics

/// Maps physical planar meters into a centered, top-down canvas viewport.
///
/// The viewport preserves one physical linear scale on both axes. Positive planar
/// Y points toward the top of the canvas, matching the explorer's top-down view.
/// A zoom scale of one fits the configured extent, larger values magnify around
/// the canvas center, and smaller values reveal more of the system.
nonisolated struct GravitySystemViewport: Equatable, Sendable {
    /// The inclusive magnification limits applied to each finite requested zoom scale.
    static let supportedZoomScaleRange: ClosedRange<Double> = 0.25...8

    let size: CGSize
    let padding: CGFloat
    let extentMeters: Double

    /// The clamped, center-relative magnification applied to the fitted physical scale.
    let zoomScale: Double

    var center: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    var pointsPerMeter: CGFloat {
        let drawableWidth = max(1, size.width - padding * 2)
        let drawableHeight = max(1, size.height - padding * 2)
        let fittedPointsPerMeter = min(drawableWidth, drawableHeight) / CGFloat(2 * extentMeters)
        return fittedPointsPerMeter * CGFloat(zoomScale)
    }

    /// The physical half-span visible from the center to either horizontal canvas edge.
    var visibleHorizontalHalfSpanMeters: Double {
        Double(size.width / 2 / pointsPerMeter)
    }

    /// The physical half-span visible from the center to either vertical canvas edge.
    var visibleVerticalHalfSpanMeters: Double {
        Double(size.height / 2 / pointsPerMeter)
    }

    init(
        size: CGSize,
        padding: CGFloat,
        extentMeters: Double,
        zoomScale: Double = 1
    ) {
        precondition(
            padding.isFinite && padding >= 0,
            "Viewport padding must be finite and nonnegative."
        )
        precondition(
            extentMeters.isFinite && extentMeters > 0,
            "Viewport extent must be finite and positive."
        )
        precondition(
            zoomScale.isFinite,
            "Viewport zoom scale must be finite."
        )
        self.size = size
        self.padding = padding
        self.extentMeters = extentMeters
        self.zoomScale = min(
            max(zoomScale, Self.supportedZoomScaleRange.lowerBound),
            Self.supportedZoomScaleRange.upperBound
        )
    }

    func point(for position: PlanarPosition) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(position.meters.x) * pointsPerMeter,
            y: center.y - CGFloat(position.meters.y) * pointsPerMeter
        )
    }

    /// Returns whether a physical position maps inside the visible canvas bounds.
    func contains(_ position: PlanarPosition) -> Bool {
        let point = point(for: position)
        return point.x >= 0
            && point.x <= size.width
            && point.y >= 0
            && point.y <= size.height
    }
}
