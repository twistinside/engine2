import Metal

/// Complete built-in Metal state proved available by resource-store construction.
///
/// This value is the one fallible boundary between Engine2's string-named
/// shader entry points and frame encoding. Its initializer resolves the engine
/// library, compiles every required pipeline, and creates every fixed state and
/// argument table. Once a ``MetalResourceStore`` publishes this value,
/// downstream render objects can retain its nonoptional typed handles without
/// repeating string lookup, closed-identity dispatch, or impossible cache-miss
/// failures. The mutable argument tables remain serialized resources owned by
/// the enclosing Render Runtime.
struct MetalRequiredResources {
    /// Library containing every built-in Engine2 shader entry point.
    let engineLibrary: any MTLLibrary

    /// Surface-lighting pipeline for ordinary PBR scene output.
    let modelPBRPipeline: any MTLRenderPipelineState

    /// Scene pipeline that emits view-space normals for diagnostics.
    let modelNormalDiagnosticPipeline: any MTLRenderPipelineState

    /// Presentation pipeline that applies exposure and tone mapping.
    let hdrToneMappedPresentationPipeline: any MTLRenderPipelineState

    /// Presentation pipeline that preserves already display-linear diagnostics.
    let linearPresentationPipeline: any MTLRenderPipelineState

    /// Ordinary opaque depth state shared by the built-in scene pipelines.
    let opaqueDepthStencilState: any MTLDepthStencilState

    /// Vertex-stage table for mesh and per-instance buffers.
    let modelArgumentTable: any MTL4ArgumentTable

    /// Fragment-stage table for per-instance and scene-lighting buffers.
    let pbrSceneArgumentTable: any MTL4ArgumentTable

    /// Fragment-stage table for HDR source texture and exposure parameters.
    let hdrPresentationArgumentTable: any MTL4ArgumentTable

    /// Resolves the complete fixed resource set for one device and compiler.
    init(device: any MTLDevice, compiler: any MTL4Compiler) throws {
        guard let engineLibrary = device.makeDefaultLibrary() else {
            throw MetalResourceStoreError.missingDefaultShaderLibrary
        }

        func makeRenderPipeline(
            vertexFunctionName: String,
            fragmentFunctionName: String,
            label: String,
            colorPixelFormat: MTLPixelFormat
        ) throws -> any MTLRenderPipelineState {
            let vertexFunction = MTL4LibraryFunctionDescriptor()
            vertexFunction.library = engineLibrary
            vertexFunction.name = vertexFunctionName

            let fragmentFunction = MTL4LibraryFunctionDescriptor()
            fragmentFunction.library = engineLibrary
            fragmentFunction.name = fragmentFunctionName

            let descriptor = MTL4RenderPipelineDescriptor()
            descriptor.label = label
            descriptor.vertexFunctionDescriptor = vertexFunction
            descriptor.fragmentFunctionDescriptor = fragmentFunction
            descriptor.rasterSampleCount = 1
            descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
            return try compiler.makeRenderPipelineState(descriptor: descriptor)
        }

        let modelPBRPipeline = try makeRenderPipeline(
            vertexFunctionName: "modelVertex",
            fragmentFunctionName: "modelPBRFragment",
            label: "USD Model PBR Pipeline",
            colorPixelFormat: MetalFrameEncoder.sceneColorPixelFormat
        )
        let modelNormalDiagnosticPipeline = try makeRenderPipeline(
            vertexFunctionName: "modelVertex",
            fragmentFunctionName: "modelNormalDiagnosticFragment",
            label: "USD Model Normal Diagnostic Pipeline",
            colorPixelFormat: MetalFrameEncoder.sceneColorPixelFormat
        )
        let hdrToneMappedPresentationPipeline = try makeRenderPipeline(
            vertexFunctionName: "hdrPresentationVertex",
            fragmentFunctionName: "hdrToneMappedPresentationFragment",
            label: "HDR Tone-Mapped Presentation Pipeline",
            colorPixelFormat: MetalFrameEncoder.destinationColorPixelFormat
        )
        let linearPresentationPipeline = try makeRenderPipeline(
            vertexFunctionName: "hdrPresentationVertex",
            fragmentFunctionName: "linearPresentationFragment",
            label: "Linear Diagnostic Presentation Pipeline",
            colorPixelFormat: MetalFrameEncoder.destinationColorPixelFormat
        )

        let opaqueDepthStencilDescriptor = MTLDepthStencilDescriptor()
        opaqueDepthStencilDescriptor.label = "Opaque Depth"
        opaqueDepthStencilDescriptor.depthCompareFunction = .less
        opaqueDepthStencilDescriptor.isDepthWriteEnabled = true
        guard let opaqueDepthStencilState = device.makeDepthStencilState(
            descriptor: opaqueDepthStencilDescriptor
        ) else {
            throw MetalResourceStoreError.missingOpaqueDepthStencilState
        }

        let modelArgumentTableDescriptor = MTL4ArgumentTableDescriptor()
        modelArgumentTableDescriptor.label = "USD Mesh Argument Table"
        modelArgumentTableDescriptor.maxBufferBindCount = 2
        let modelArgumentTable = try device.makeArgumentTable(descriptor: modelArgumentTableDescriptor)

        let pbrSceneArgumentTableDescriptor = MTL4ArgumentTableDescriptor()
        pbrSceneArgumentTableDescriptor.label = "PBR Scene Argument Table"
        // The fragment function consumes the current per-draw instance at
        // buffer index 1 and the frame's light-only scene record at index 2.
        // Capacity includes the unused vertex-only index 0 as well.
        pbrSceneArgumentTableDescriptor.maxBufferBindCount = 3
        let pbrSceneArgumentTable = try device.makeArgumentTable(descriptor: pbrSceneArgumentTableDescriptor)

        let hdrPresentationArgumentTableDescriptor = MTL4ArgumentTableDescriptor()
        hdrPresentationArgumentTableDescriptor.label = "HDR Presentation Argument Table"
        hdrPresentationArgumentTableDescriptor.maxBufferBindCount = 1
        hdrPresentationArgumentTableDescriptor.maxTextureBindCount = 1
        let hdrPresentationArgumentTable = try device.makeArgumentTable(
            descriptor: hdrPresentationArgumentTableDescriptor
        )

        self.engineLibrary = engineLibrary
        self.modelPBRPipeline = modelPBRPipeline
        self.modelNormalDiagnosticPipeline = modelNormalDiagnosticPipeline
        self.hdrToneMappedPresentationPipeline = hdrToneMappedPresentationPipeline
        self.linearPresentationPipeline = linearPresentationPipeline
        self.opaqueDepthStencilState = opaqueDepthStencilState
        self.modelArgumentTable = modelArgumentTable
        self.pbrSceneArgumentTable = pbrSceneArgumentTable
        self.hdrPresentationArgumentTable = hdrPresentationArgumentTable
    }
}
