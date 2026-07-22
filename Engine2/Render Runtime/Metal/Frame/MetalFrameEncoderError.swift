/// Failures encountered while creating required phases of a Metal frame.
///
/// These errors are independent of whether the caller targets a MetalKit
/// drawable or an offscreen texture. The caller owns terminal-error policy.
nonisolated enum MetalFrameEncoderError: Error, Equatable {
    case missingSceneEncoder
    case missingPresentationEncoder
}
