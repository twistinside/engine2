import Metal

/// Fixed color-composition policies used by built-in Render pipelines.
///
/// Keeping this vocabulary closed makes every blend decision visible during
/// eager pipeline construction. Draw encoding selects only already-compiled
/// pipeline state and never mutates attachment policy per frame.
enum MetalRenderBlendMode {
    case opaque
    case premultipliedAlpha
    case additive

    /// Applies this policy to one Metal 4 color attachment descriptor.
    func apply(to attachment: MTL4RenderPipelineColorAttachmentDescriptor) {
        switch self {
        case .opaque:
            attachment.blendingState = .disabled

        case .premultipliedAlpha:
            attachment.blendingState = .enabled
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.rgbBlendOperation = .add
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            attachment.alphaBlendOperation = .add

        case .additive:
            attachment.blendingState = .enabled
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .one
            attachment.rgbBlendOperation = .add
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .one
            attachment.alphaBlendOperation = .add
        }
    }
}
