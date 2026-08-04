/// Failure that prevents a renderer-only workload from producing valid timing.
nonisolated enum RenderBenchmarkError: Error, Equatable, Sendable {
    case emptyWorkload
    case invalidWarmupIterationCount(Int)
    case invalidMeasuredIterationCount(Int)
    case missingMetalDevice
    case metal4Unsupported
    case invalidFrameResourceCount(expected: Int, actual: Int)
    case nonincreasingSequence(previous: UInt64, current: UInt64)
    case heterogeneousPixelSize(
        expected: RenderPixelSize,
        actual: RenderPixelSize,
        sequence: UInt64
    )
    case nonfiniteClearColor(sequence: UInt64)
    case invalidViewpoint(sequence: UInt64)
    case invalidPresentation(
        sequence: UInt64,
        reason: RenderFrameProjectionError
    )
    case instanceLimitExceeded(
        sequence: UInt64,
        requested: Int,
        maximum: Int
    )
    case missingModel(sequence: UInt64, meshID: MeshID)
    case incompleteModel(sequence: UInt64, meshID: MeshID)
    case missingDestinationTexture(RenderPixelSize)
    case missingDepthTexture(RenderPixelSize)
    case missingCommandBuffer(sequence: UInt64)
    case resourceConstructionFailed(String)
    case frameEncodingFailed(sequence: UInt64, description: String)
    case gpuExecutionFailed(sequence: UInt64, description: String)
    case invalidGPUInterval(
        sequence: UInt64,
        startSeconds: Double,
        endSeconds: Double
    )
    case measuredSampleCountMismatch(expected: Int, actual: Int)

    var isGPUFeedbackFailure: Bool {
        switch self {
        case .gpuExecutionFailed,
             .invalidGPUInterval:
            true

        case .emptyWorkload,
             .invalidWarmupIterationCount,
             .invalidMeasuredIterationCount,
             .missingMetalDevice,
             .metal4Unsupported,
             .invalidFrameResourceCount,
             .nonincreasingSequence,
             .heterogeneousPixelSize,
             .nonfiniteClearColor,
             .invalidViewpoint,
             .invalidPresentation,
             .instanceLimitExceeded,
             .missingModel,
             .incompleteModel,
             .missingDestinationTexture,
             .missingDepthTexture,
             .missingCommandBuffer,
             .resourceConstructionFailed,
             .frameEncodingFailed,
             .measuredSampleCountMismatch:
            false
        }
    }
}

extension RenderBenchmarkError: CustomStringConvertible {
    var description: String {
        switch self {
        case .emptyWorkload:
            "A render benchmark requires at least one frame."

        case let .invalidWarmupIterationCount(count):
            "Warm-up iteration count must be nonnegative; received \(count)."

        case let .invalidMeasuredIterationCount(count):
            "Measured iteration count must be positive; received \(count)."

        case .missingMetalDevice:
            "The system has no default Metal device."

        case .metal4Unsupported:
            "The selected Metal device does not support the Metal 4 GPU family."

        case let .invalidFrameResourceCount(expected, actual):
            "The benchmark requires \(expected) frame slots; received \(actual)."

        case let .nonincreasingSequence(previous, current):
            "Frame sequence \(current) does not follow \(previous) in strictly increasing order."

        case let .heterogeneousPixelSize(expected, actual, sequence):
            "Frame \(sequence) requests \(actual.width)x\(actual.height); expected \(expected.width)x\(expected.height)."

        case let .nonfiniteClearColor(sequence):
            "Frame \(sequence) contains a nonfinite clear color."

        case let .invalidViewpoint(sequence):
            "Frame \(sequence) contains an invalid viewpoint."

        case let .invalidPresentation(sequence, reason):
            "Frame \(sequence) contains invalid presentation state: \(reason)."

        case let .instanceLimitExceeded(sequence, requested, maximum):
            "Frame \(sequence) contains \(requested) instances; the renderer supports \(maximum)."

        case let .missingModel(sequence, meshID):
            "Frame \(sequence) references unavailable model \(meshID)."

        case let .incompleteModel(sequence, meshID):
            "Frame \(sequence) references model \(meshID) without complete indexed geometry."

        case let .missingDestinationTexture(size):
            "Metal could not allocate a private \(size.width)x\(size.height) benchmark destination."

        case let .missingDepthTexture(size):
            "Metal could not allocate a private \(size.width)x\(size.height) benchmark depth target."

        case let .missingCommandBuffer(sequence):
            "Metal could not create a command buffer for frame \(sequence)."

        case let .resourceConstructionFailed(description):
            "Render benchmark resource construction failed: \(description)"

        case let .frameEncodingFailed(sequence, description):
            "Metal command encoding failed for frame \(sequence): \(description)"

        case let .gpuExecutionFailed(sequence, description):
            "Metal GPU execution failed for frame \(sequence): \(description)"

        case let .invalidGPUInterval(sequence, startSeconds, endSeconds):
            "Frame \(sequence) reported invalid GPU times \(startSeconds)...\(endSeconds)."

        case let .measuredSampleCountMismatch(expected, actual):
            "The benchmark completed \(actual) measured samples; expected \(expected)."
        }
    }
}
