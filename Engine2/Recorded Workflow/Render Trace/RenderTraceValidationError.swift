/// Invalid durable Render trace data that cannot form trusted renderer input.
///
/// The persistence boundary reports malformed scalar values before constructing
/// domain types whose ordinary initializers assume trusted in-process values.
nonisolated enum RenderTraceValidationError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(UInt32)
    case emptyFrames
    case nonincreasingFrameSequence(previous: UInt64, current: UInt64)
    case nonfiniteVector
    case invalidQuaternion
    case invalidCameraProjection
    case invalidCameraTransform
    case invalidEntityIndex
    case invalidEntityGeneration
    case duplicateEntityIdentity(EntityID)
    case invalidPixelSize(RenderPixelSizeError)
    case invalidExposure
    case invalidClearColor
}
