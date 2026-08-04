import Metal

/// Validated ordered workload retained by one renderer-only benchmark.
///
/// A run uses one homogeneous pixel size so every frame slot can allocate its
/// private attachments once during construction and reuse them through warm-up
/// and all measured iterations.
nonisolated struct RenderBenchmarkWorkload: Sendable {
    let frames: [RenderBenchmarkFrame]
    let pixelSize: RenderPixelSize

    init(frames: [RenderBenchmarkFrame]) throws(RenderBenchmarkError) {
        guard let firstFrame = frames.first else {
            throw .emptyWorkload
        }

        var previousSequence = firstFrame.sequence
        for frame in frames.dropFirst() {
            guard frame.sequence > previousSequence else {
                throw .nonincreasingSequence(
                    previous: previousSequence,
                    current: frame.sequence
                )
            }
            previousSequence = frame.sequence
        }

        let pixelSize = firstFrame.settings.size
        for frame in frames {
            guard frame.settings.size == pixelSize else {
                throw .heterogeneousPixelSize(
                    expected: pixelSize,
                    actual: frame.settings.size,
                    sequence: frame.sequence
                )
            }
            let clearColor = frame.clearColor
            guard clearColor.red.isFinite,
                  clearColor.green.isFinite,
                  clearColor.blue.isFinite,
                  clearColor.alpha.isFinite
            else {
                throw .nonfiniteClearColor(sequence: frame.sequence)
            }
        }

        self.frames = frames
        self.pixelSize = pixelSize
    }
}
