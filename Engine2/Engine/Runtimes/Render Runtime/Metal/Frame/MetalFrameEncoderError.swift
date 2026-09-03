import Metal

/// Failures encountered while creating required phases of a Metal frame.
///
/// These errors are independent of the caller-owned destination texture. The
/// caller owns terminal-error policy.
nonisolated enum MetalFrameEncoderError: Error, Equatable {
    case mismatchedTargetDimensions
    case missingSceneEncoder
    case missingPresentationEncoder
    case unexpectedTargetPixelFormats(sceneColor: MTLPixelFormat, depth: MTLPixelFormat, destination: MTLPixelFormat)
}
