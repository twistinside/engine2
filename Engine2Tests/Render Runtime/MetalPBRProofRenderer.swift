import Dispatch
import Metal
@testable import Engine2

/// Test-only Metal 4 renderer for the isolated direct-light BRDF proof.
///
/// The renderer owns one analytic sphere target, a provisional parameter
/// buffer, proof-only pipelines, and their residency set. It deliberately does
/// not use the application's drawable path or establish a production material
/// binding. The only artifact intended for production reuse is the shader
/// evaluator called by these proof pipelines.
@MainActor
final class MetalPBRProofRenderer {
    static let width = 65
    static let height = 65
    static let colorPixelFormat = MTLPixelFormat.rgba16Float

    private let resources: MetalResourceStore
    private let commandAllocator: any MTL4CommandAllocator
    private let parametersBuffer: any MTLBuffer
    private let colorTexture: any MTLTexture
    private let argumentTable: any MTL4ArgumentTable
    private let residencySet: any MTLResidencySet
    private let pipelines: [PBRProofOutput: any MTLRenderPipelineState]
    private var canSubmit = true

    init() throws {
        let resources = try MetalResourceStore(
            renderAssetCatalog: RenderAssetCatalog(models: [:]),
            frameCount: 1
        )
        guard let commandAllocator = resources.device.makeCommandAllocator() else {
            throw MetalPBRProofRendererError.missingCommandAllocator
        }
        guard let parametersBuffer = resources.device.makeBuffer(
            length: MemoryLayout<PBRProofParameters>.stride,
            options: [.storageModeShared]
        ) else {
            throw MetalPBRProofRendererError.missingParametersBuffer
        }

        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: Self.colorPixelFormat,
            width: Self.width,
            height: Self.height,
            mipmapped: false
        )
        colorDescriptor.storageMode = .shared
        colorDescriptor.usage = [.renderTarget]
        guard let colorTexture = resources.device.makeTexture(
            descriptor: colorDescriptor
        ) else {
            throw MetalPBRProofRendererError.missingColorTexture
        }

        let argumentDescriptor = MTL4ArgumentTableDescriptor()
        argumentDescriptor.label = "PBR Proof Parameters"
        argumentDescriptor.maxBufferBindCount = 1
        let argumentTable = try resources.device.makeArgumentTable(
            descriptor: argumentDescriptor
        )
        argumentTable.setAddress(parametersBuffer.gpuAddress, index: 0)

        let residencyDescriptor = MTLResidencySetDescriptor()
        residencyDescriptor.label = "PBR Proof Resources"
        residencyDescriptor.initialCapacity = 2
        let residencySet = try resources.device.makeResidencySet(
            descriptor: residencyDescriptor
        )
        residencySet.addAllocation(parametersBuffer)
        residencySet.addAllocation(colorTexture)
        residencySet.commit()

        let library = try resources.shaderLibrary(for: .engine)
        var pipelines: [PBRProofOutput: any MTLRenderPipelineState] = [:]
        for output in PBRProofOutput.allCases {
            let vertexFunction = MTL4LibraryFunctionDescriptor()
            vertexFunction.library = library
            vertexFunction.name = "pbrProofVertex"

            let fragmentFunction = MTL4LibraryFunctionDescriptor()
            fragmentFunction.library = library
            fragmentFunction.name = output.fragmentFunctionName

            let pipelineDescriptor = MTL4RenderPipelineDescriptor()
            pipelineDescriptor.label = "PBR Proof \(output)"
            pipelineDescriptor.vertexFunctionDescriptor = vertexFunction
            pipelineDescriptor.fragmentFunctionDescriptor = fragmentFunction
            pipelineDescriptor.rasterSampleCount = 1
            pipelineDescriptor.colorAttachments[0].pixelFormat = Self.colorPixelFormat
            pipelines[output] = try resources.compiler.makeRenderPipelineState(
                descriptor: pipelineDescriptor
            )
        }

        self.resources = resources
        self.commandAllocator = commandAllocator
        self.parametersBuffer = parametersBuffer
        self.colorTexture = colorTexture
        self.argumentTable = argumentTable
        self.residencySet = residencySet
        self.pipelines = pipelines
    }

    /// Renders one diagnostic and returns raw linear RGBA values in row order.
    func render(
        _ output: PBRProofOutput,
        parameters: PBRProofParameters = .validation
    ) throws -> [SIMD4<Float>] {
        guard canSubmit else {
            throw MetalPBRProofRendererError.unusableAfterTimeout
        }
        guard let pipeline = pipelines[output] else {
            throw MetalPBRProofRendererError.missingPipeline(output)
        }

        parametersBuffer.contents().storeBytes(
            of: parameters,
            as: PBRProofParameters.self
        )
        commandAllocator.reset()

        guard let commandBuffer = resources.device.makeCommandBuffer() else {
            throw MetalPBRProofRendererError.missingCommandBuffer
        }
        commandBuffer.beginCommandBuffer(allocator: commandAllocator)
        // `beginCommandBuffer` clears command-buffer-specific residency, so the
        // proof set must be declared after beginning every submission.
        commandBuffer.useResidencySet(residencySet)

        let renderPass = MTL4RenderPassDescriptor()
        renderPass.colorAttachments[0].texture = colorTexture
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 0
        )

        guard let encoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPass,
            options: []
        ) else {
            commandBuffer.endCommandBuffer()
            throw MetalPBRProofRendererError.missingRenderEncoder
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setArgumentTable(argumentTable, stages: .fragment)
        encoder.drawPrimitives(
            primitiveType: .triangle,
            vertexStart: 0,
            vertexCount: 3
        )
        encoder.endEncoding()
        commandBuffer.endCommandBuffer()

        let submission = MetalOffscreenTestSubmission(
            retaining: [self as AnyObject]
        )
        let commitOptions = MTL4CommitOptions()
        commitOptions.addFeedbackHandler { feedback in
            submission.complete(feedbackError: feedback.error)
        }
        resources.commandQueue.commit([commandBuffer], options: commitOptions)

        do {
            try submission.waitForCompletion(timeout: .now() + 5)
        } catch MetalOffscreenTestSubmissionError.timedOut {
            // The feedback handler still owns this renderer and its resources.
            // Prevent a caller from reusing them while that work remains live.
            canSubmit = false
            throw MetalPBRProofRendererError.timedOut
        }

        return readLinearPixels()
    }

    private func readLinearPixels() -> [SIMD4<Float>] {
        let componentCount = Self.width * Self.height * 4
        var halfComponents = [Float16](repeating: 0, count: componentCount)
        halfComponents.withUnsafeMutableBytes { bytes in
            colorTexture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: Self.width * 4 * MemoryLayout<Float16>.stride,
                from: MTLRegionMake2D(0, 0, Self.width, Self.height),
                mipmapLevel: 0
            )
        }

        var pixels: [SIMD4<Float>] = []
        pixels.reserveCapacity(Self.width * Self.height)
        for componentIndex in stride(
            from: 0,
            to: halfComponents.count,
            by: 4
        ) {
            pixels.append(
                SIMD4<Float>(
                    Float(halfComponents[componentIndex]),
                    Float(halfComponents[componentIndex + 1]),
                    Float(halfComponents[componentIndex + 2]),
                    Float(halfComponents[componentIndex + 3])
                )
            )
        }
        return pixels
    }
}
