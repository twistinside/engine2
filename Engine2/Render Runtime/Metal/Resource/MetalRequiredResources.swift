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

    /// Opaque displaced terrain-and-ocean pipeline for a terrestrial planet.
    let terrestrialPlanetSurfacePipeline: any MTLRenderPipelineState

    /// Planet-surface pipeline that emits view-space normals for diagnostics.
    let terrestrialPlanetNormalDiagnosticPipeline: any MTLRenderPipelineState

    /// Premultiplied cloud-shell pipeline drawn after opaque surfaces.
    let terrestrialPlanetCloudPipeline: any MTLRenderPipelineState

    /// Opacity-weighted additive atmosphere pipeline drawn after cloud shells.
    let terrestrialPlanetAtmospherePipeline: any MTLRenderPipelineState

    /// Presentation pipeline that applies exposure and tone mapping.
    let hdrToneMappedPresentationPipeline: any MTLRenderPipelineState

    /// Presentation pipeline that preserves already display-linear diagnostics.
    let linearPresentationPipeline: any MTLRenderPipelineState

    /// Ordinary opaque depth state shared by the built-in scene pipelines.
    let opaqueDepthStencilState: any MTLDepthStencilState

    /// Read-only depth state for ordered cloud and atmosphere shells.
    let translucentDepthStencilState: any MTLDepthStencilState

    /// Vertex-stage table for mesh and per-instance buffers.
    let modelArgumentTable: any MTL4ArgumentTable

    /// Fragment-stage table for per-instance and scene-lighting buffers.
    let pbrSceneArgumentTable: any MTL4ArgumentTable

    /// Shared vertex-and-fragment table for planet buffers and sampled maps.
    let terrestrialPlanetArgumentTable: any MTL4ArgumentTable

    /// Repeating equirectangular sampler shared by every planet map.
    let terrestrialPlanetSamplerState: any MTLSamplerState

    /// Fragment-stage table for HDR source texture and exposure parameters.
    let hdrPresentationArgumentTable: any MTL4ArgumentTable

    /// Resolves the complete fixed resource set for one device and compiler.
    init(device: any MTLDevice, compiler: any MTL4Compiler) throws {
        guard let engineLibrary = device.makeDefaultLibrary() else {
            throw MetalResourceStoreError.missingDefaultShaderLibrary
        }

        let pipelineCompiler = MetalRenderPipelineCompiler(
            compiler: compiler,
            library: engineLibrary
        )
        let modelPBRPipeline = try pipelineCompiler.compile(
            vertexFunctionName: "modelVertex",
            fragmentFunctionName: "modelPBRFragment",
            label: "USD Model PBR Pipeline",
            colorPixelFormat: MetalFrameEncoder.sceneColorPixelFormat
        )
        let modelNormalDiagnosticPipeline = try pipelineCompiler.compile(
            vertexFunctionName: "modelVertex",
            fragmentFunctionName: "modelNormalDiagnosticFragment",
            label: "USD Model Normal Diagnostic Pipeline",
            colorPixelFormat: MetalFrameEncoder.sceneColorPixelFormat
        )
        let terrestrialPlanetSurfacePipeline = try pipelineCompiler.compile(
            vertexFunctionName: "terrestrialPlanetSurfaceVertex",
            fragmentFunctionName: "terrestrialPlanetSurfaceFragment",
            label: "Terrestrial Planet Surface Pipeline",
            colorPixelFormat: MetalFrameEncoder.sceneColorPixelFormat
        )
        let terrestrialPlanetNormalDiagnosticPipeline = try pipelineCompiler.compile(
            vertexFunctionName: "terrestrialPlanetSurfaceVertex",
            fragmentFunctionName: "terrestrialPlanetNormalDiagnosticFragment",
            label: "Terrestrial Planet Normal Diagnostic Pipeline",
            colorPixelFormat: MetalFrameEncoder.sceneColorPixelFormat
        )
        let terrestrialPlanetCloudPipeline = try pipelineCompiler.compile(
            vertexFunctionName: "terrestrialPlanetCloudVertex",
            fragmentFunctionName: "terrestrialPlanetCloudFragment",
            label: "Terrestrial Planet Cloud Pipeline",
            colorPixelFormat: MetalFrameEncoder.sceneColorPixelFormat,
            blendMode: .premultipliedAlpha
        )
        let terrestrialPlanetAtmospherePipeline = try pipelineCompiler.compile(
            vertexFunctionName: "terrestrialPlanetAtmosphereVertex",
            fragmentFunctionName: "terrestrialPlanetAtmosphereFragment",
            label: "Terrestrial Planet Atmosphere Pipeline",
            colorPixelFormat: MetalFrameEncoder.sceneColorPixelFormat,
            blendMode: .additive
        )
        let hdrToneMappedPresentationPipeline = try pipelineCompiler.compile(
            vertexFunctionName: "hdrPresentationVertex",
            fragmentFunctionName: "hdrToneMappedPresentationFragment",
            label: "HDR Tone-Mapped Presentation Pipeline",
            colorPixelFormat: MetalFrameEncoder.destinationColorPixelFormat
        )
        let linearPresentationPipeline = try pipelineCompiler.compile(
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

        let translucentDepthStencilDescriptor = MTLDepthStencilDescriptor()
        translucentDepthStencilDescriptor.label = "Translucent Read-Only Depth"
        translucentDepthStencilDescriptor.depthCompareFunction = .lessEqual
        translucentDepthStencilDescriptor.isDepthWriteEnabled = false
        guard let translucentDepthStencilState = device.makeDepthStencilState(
            descriptor: translucentDepthStencilDescriptor
        ) else {
            throw MetalResourceStoreError.missingTranslucentDepthStencilState
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

        let terrestrialPlanetArgumentTableDescriptor = MTL4ArgumentTableDescriptor()
        terrestrialPlanetArgumentTableDescriptor.label = "Terrestrial Planet Argument Table"
        terrestrialPlanetArgumentTableDescriptor.maxBufferBindCount = 3
        terrestrialPlanetArgumentTableDescriptor.maxTextureBindCount = 4
        terrestrialPlanetArgumentTableDescriptor.maxSamplerStateBindCount = 1
        let terrestrialPlanetArgumentTable = try device.makeArgumentTable(
            descriptor: terrestrialPlanetArgumentTableDescriptor
        )

        let terrestrialPlanetSamplerDescriptor = MTLSamplerDescriptor()
        terrestrialPlanetSamplerDescriptor.label = "Terrestrial Planet Equirectangular Sampler"
        terrestrialPlanetSamplerDescriptor.minFilter = .linear
        terrestrialPlanetSamplerDescriptor.magFilter = .linear
        terrestrialPlanetSamplerDescriptor.mipFilter = .linear
        terrestrialPlanetSamplerDescriptor.maxAnisotropy = 8
        terrestrialPlanetSamplerDescriptor.sAddressMode = .repeat
        terrestrialPlanetSamplerDescriptor.tAddressMode = .clampToEdge
        guard let terrestrialPlanetSamplerState = device.makeSamplerState(
            descriptor: terrestrialPlanetSamplerDescriptor
        ) else {
            throw MetalResourceStoreError.missingTerrestrialPlanetSamplerState
        }
        terrestrialPlanetArgumentTable.setSamplerState(
            terrestrialPlanetSamplerState.gpuResourceID,
            index: 0
        )

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
        self.terrestrialPlanetSurfacePipeline = terrestrialPlanetSurfacePipeline
        self.terrestrialPlanetNormalDiagnosticPipeline = terrestrialPlanetNormalDiagnosticPipeline
        self.terrestrialPlanetCloudPipeline = terrestrialPlanetCloudPipeline
        self.terrestrialPlanetAtmospherePipeline = terrestrialPlanetAtmospherePipeline
        self.hdrToneMappedPresentationPipeline = hdrToneMappedPresentationPipeline
        self.linearPresentationPipeline = linearPresentationPipeline
        self.opaqueDepthStencilState = opaqueDepthStencilState
        self.translucentDepthStencilState = translucentDepthStencilState
        self.modelArgumentTable = modelArgumentTable
        self.pbrSceneArgumentTable = pbrSceneArgumentTable
        self.terrestrialPlanetArgumentTable = terrestrialPlanetArgumentTable
        self.terrestrialPlanetSamplerState = terrestrialPlanetSamplerState
        self.hdrPresentationArgumentTable = hdrPresentationArgumentTable
    }
}
