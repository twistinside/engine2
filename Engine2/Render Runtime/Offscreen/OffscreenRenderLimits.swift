/// Caller-selected safety limits for one offscreen rendering capability.
///
/// Limits are overridable host policy rather than renderer correctness
/// constraints or a guarantee of device capability. A host may deliberately
/// construct larger limits when it is prepared to absorb the corresponding
/// allocation, GPU, and readback cost. The current HDR, depth, destination, and
/// detached readback path requires approximately 20 bytes per requested pixel
/// before allocator, model, and driver overhead.
nonisolated struct OffscreenRenderLimits: Equatable, Sendable {
    /// Conservative policy suitable for general-purpose callers.
    static let conservative = OffscreenRenderLimits(
        maxDimension: 8_192,
        maxPixelCount: 16_777_216
    )

    let maxDimension: Int
    let maxPixelCount: Int

    /// Creates trusted positive bounds for accepted render sizes.
    init(
        maxDimension: Int,
        maxPixelCount: Int
    ) {
        precondition(
            maxDimension > 0,
            "The maximum offscreen render dimension must be positive."
        )
        precondition(
            maxPixelCount > 0,
            "The maximum offscreen render pixel count must be positive."
        )
        self.maxDimension = maxDimension
        self.maxPixelCount = maxPixelCount
    }

    /// Returns whether a validated size falls within both policy bounds.
    func permits(_ size: RenderPixelSize) -> Bool {
        size.width <= maxDimension
            && size.height <= maxDimension
            && size.pixelCount <= maxPixelCount
    }
}
