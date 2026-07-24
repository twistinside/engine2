import CoreGraphics
import Metal

/// Caller-owned resources and policy consumed by one Metal frame encoding.
///
/// Grouping the three related targets with their frame slot and presentation
/// settings keeps the encoder boundary readable while preserving explicit
/// caller ownership. Construction proves the targets agree with one another
/// and with the pipelines compiled by ``MetalFrameEncoder``.
@MainActor
struct MetalFrameEncodingInputs {
    let frameResources: FrameResources
    let sceneColorTexture: any MTLTexture
    let depthTexture: any MTLTexture
    let destinationTexture: any MTLTexture
    let clearColor: MTLClearColor
    let outputMode: RenderOutputMode
    let exposure: ManualExposure

    /// Pixel extent shared by all three validated targets.
    var drawableSize: CGSize {
        CGSize(
            width: destinationTexture.width,
            height: destinationTexture.height
        )
    }

    /// Creates one coherent encoding input after validating target contracts.
    init(
        frameResources: FrameResources,
        sceneColorTexture: any MTLTexture,
        depthTexture: any MTLTexture,
        destinationTexture: any MTLTexture,
        clearColor: MTLClearColor,
        outputMode: RenderOutputMode,
        exposure: ManualExposure = .validation
    ) throws {
        guard sceneColorTexture.width == depthTexture.width,
              sceneColorTexture.height == depthTexture.height,
              sceneColorTexture.width == destinationTexture.width,
              sceneColorTexture.height == destinationTexture.height
        else {
            throw MetalFrameEncoderError.mismatchedTargetDimensions
        }
        guard sceneColorTexture.pixelFormat
                == MetalFrameEncoder.sceneColorPixelFormat,
              depthTexture.pixelFormat == MetalFrameEncoder.depthPixelFormat,
              destinationTexture.pixelFormat
                == MetalFrameEncoder.destinationColorPixelFormat
        else {
            throw MetalFrameEncoderError.unexpectedTargetPixelFormats(
                sceneColor: sceneColorTexture.pixelFormat,
                depth: depthTexture.pixelFormat,
                destination: destinationTexture.pixelFormat
            )
        }

        self.frameResources = frameResources
        self.sceneColorTexture = sceneColorTexture
        self.depthTexture = depthTexture
        self.destinationTexture = destinationTexture
        self.clearColor = clearColor
        self.outputMode = outputMode
        self.exposure = exposure
    }
}
