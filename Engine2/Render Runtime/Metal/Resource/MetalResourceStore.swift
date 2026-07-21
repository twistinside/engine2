import Metal
import MetalKit

/// Device-scoped owner for long-lived Metal backend objects.
///
/// The store is private infrastructure inside a Render Runtime. Game Content
/// supplies backend-neutral asset references, while this object resolves and
/// retains the corresponding device objects for exactly one `MTLDevice`.
@MainActor
final class MetalResourceStore {
    /// App-owned diagnostic boundary shared with the Render Runtime.
    private let diagnostics: DiagnosticsEmitter

    /// The root of every resource in this store. A different device requires a
    /// different store because Metal objects cannot move between devices.
    let device: any MTLDevice

    /// Metal 4 compiler used for pipeline creation and future archive-backed
    /// compilation. Pipeline compilation is kept out of the draw path.
    let compiler: any MTL4Compiler

    /// Metal 4 queue through which the renderer submits reusable command
    /// buffers and on which the store registers residency sets.
    let commandQueue: any MTL4CommandQueue

    /// Residency organization for allocations retained by this store.
    let residency: MetalResidencyManager

    /// Fixed ring of allocator/buffer pairs used by the renderer.
    private(set) var frames: [FrameResources] = []

    private var shaderLibraries: [
        MetalShaderLibraryID: any MTLLibrary
    ] = [:]

    private var renderPipelineStates: [
        MetalRenderPipelineID: any MTLRenderPipelineState
    ] = [:]

    private var depthStencilStates: [
        MetalDepthStencilStateID: any MTLDepthStencilState
    ] = [:]

    private var argumentTables: [
        MetalArgumentTableID: any MTL4ArgumentTable
    ] = [:]

    private var models: [MeshID: USDRenderModel] = [:]

    /// Validated authored descriptions retained as CPU-side Render resources.
    ///
    /// The current material count does not justify a separate GPU table. Each
    /// frame resolves these values into its existing per-draw instance records,
    /// while this dictionary preserves the Game Content identity boundary.
    private let materialDescriptions: [
        MaterialID: PBRMaterialDescription
    ]

    /// Selects the system's default Metal device and creates a complete store
    /// containing the renderer's required built-in resources.
    convenience init(
        renderAssetCatalog: RenderAssetCatalog,
        frameCount: Int = MetalRenderer.maximumFramesInFlight,
        diagnostics: DiagnosticsEmitter = DiagnosticsEmitter()
    ) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalResourceStoreError.missingDevice
        }

        try self.init(
            device: device,
            renderAssetCatalog: renderAssetCatalog,
            frameCount: frameCount,
            diagnostics: diagnostics
        )
    }

    /// Creates a resource store for an explicitly selected device.
    init(
        device: any MTLDevice,
        renderAssetCatalog: RenderAssetCatalog,
        frameCount: Int = MetalRenderer.maximumFramesInFlight,
        diagnostics: DiagnosticsEmitter = DiagnosticsEmitter()
    ) throws {
        guard frameCount > 0 else {
            throw MetalResourceStoreError.invalidFrameCount(frameCount)
        }

        // Validate the closed authored-material vocabulary before allocating or
        // compiling backend state. A malformed content package therefore fails
        // during Render Runtime construction, never halfway through a frame.
        do {
            try renderAssetCatalog.validateMaterialCoverage()
        } catch {
            diagnostics.logRenderPreparationFailed(stage: .catalogValidation, error: error)
            throw error
        }

        guard let commandQueue = device.makeMTL4CommandQueue() else {
            let error = MetalResourceStoreError.missingCommandQueue
            diagnostics.logRenderPreparationFailed(stage: .commandQueue, error: error)
            throw error
        }

        let compilerDescriptor = MTL4CompilerDescriptor()
        compilerDescriptor.label = "Engine2 Render Compiler"
        let compiler: any MTL4Compiler
        do {
            compiler = try device.makeCompiler(descriptor: compilerDescriptor)
        } catch {
            diagnostics.logRenderPreparationFailed(stage: .compiler, error: error)
            throw error
        }

        let residency: MetalResidencyManager
        do {
            residency = try MetalResidencyManager(
                device: device,
                commandQueue: commandQueue,
                staticAssetCapacity: max(renderAssetCatalog.models.count * 4, 1),
                frameResourceCapacity: frameCount * 3
            )
        } catch {
            diagnostics.logRenderPreparationFailed(stage: .residency, error: error)
            throw error
        }

        self.diagnostics = diagnostics
        self.device = device
        self.compiler = compiler
        self.commandQueue = commandQueue
        self.residency = residency
        self.materialDescriptions = renderAssetCatalog.materials

        // Build the small required set eagerly so frame encoding performs only
        // deterministic dictionary lookup and never triggers compilation.
        do {
            try makeFrameResources(count: frameCount)
        } catch {
            diagnostics.logRenderPreparationFailed(stage: .frameResources, error: error)
            throw error
        }
        do {
            try loadShaderLibrary(.engine)
        } catch {
            diagnostics.logRenderPreparationFailed(stage: .shaderLibrary, error: error)
            throw error
        }
        do {
            try loadRenderPipeline(.modelPBR)
            try loadRenderPipeline(.modelNormalDiagnostic)
            try loadRenderPipeline(.hdrToneMappedPresentation)
            try loadRenderPipeline(.linearPresentation)
        } catch {
            diagnostics.logRenderPreparationFailed(stage: .pipeline, error: error)
            throw error
        }
        do {
            try loadDepthStencilState(.opaque)
        } catch {
            diagnostics.logRenderPreparationFailed(stage: .fixedFunctionState, error: error)
            throw error
        }
        do {
            try loadArgumentTable(.model)
            try loadArgumentTable(.pbrScene)
            try loadArgumentTable(.hdrPresentation)
        } catch {
            diagnostics.logRenderPreparationFailed(stage: .argumentTables, error: error)
            throw error
        }
        do {
            try loadModels(from: renderAssetCatalog)
        } catch {
            diagnostics.logRenderPreparationFailed(stage: .models, error: error)
            throw error
        }
        reportResourceInventory()
    }

    /// Returns a previously loaded shader library.
    func shaderLibrary(
        for id: MetalShaderLibraryID
    ) throws -> any MTLLibrary {
        guard let library = shaderLibraries[id] else {
            throw MetalResourceStoreError.missingShaderLibrary(id)
        }

        return library
    }

    /// Returns a pipeline that was compiled before frame encoding began.
    func renderPipelineState(
        for id: MetalRenderPipelineID
    ) throws -> any MTLRenderPipelineState {
        guard let state = renderPipelineStates[id] else {
            throw MetalResourceStoreError.missingRenderPipeline(id)
        }

        return state
    }

    /// Returns an immutable depth-stencil state by backend identity.
    func depthStencilState(
        for id: MetalDepthStencilStateID
    ) throws -> any MTLDepthStencilState {
        guard let state = depthStencilStates[id] else {
            throw MetalResourceStoreError.missingDepthStencilState(id)
        }

        return state
    }

    /// Returns a Metal 4 resource-binding table by backend identity.
    func argumentTable(
        for id: MetalArgumentTableID
    ) throws -> any MTL4ArgumentTable {
        guard let table = argumentTables[id] else {
            throw MetalResourceStoreError.missingArgumentTable(id)
        }

        return table
    }

    /// Resolves an abstract snapshot mesh identity to a retained backend model.
    func model(for id: MeshID) -> USDRenderModel? {
        models[id]
    }

    /// Resolves one Game Content identity to its retained authored factors.
    ///
    /// Store construction validates exhaustive coverage, so a missing value
    /// here would indicate that a future mutation or catalog-loading path
    /// violated that invariant. Keep the lookup throwing rather than inventing
    /// a fallback appearance or crashing inside frame encoding.
    func materialDescription(
        for id: MaterialID
    ) throws -> PBRMaterialDescription {
        guard let description = materialDescriptions[id] else {
            throw RenderAssetCatalogError.missingMaterialDescriptions([id])
        }

        return description
    }

    /// Loads the shader library defined by a closed Render Runtime identity.
    @discardableResult
    private func loadShaderLibrary(
        _ id: MetalShaderLibraryID
    ) throws -> any MTLLibrary {
        if let existingLibrary = shaderLibraries[id] {
            return existingLibrary
        }

        let library: any MTLLibrary

        switch id {
        case .engine:
            guard let defaultLibrary = device.makeDefaultLibrary() else {
                throw MetalResourceStoreError.missingDefaultShaderLibrary
            }
            library = defaultLibrary
        }

        shaderLibraries[id] = library
        return library
    }

    /// Compiles the Metal 4 render pipeline defined by a closed identity.
    @discardableResult
    func loadRenderPipeline(
        _ id: MetalRenderPipelineID
    ) throws -> any MTLRenderPipelineState {
        if let existingState = renderPipelineStates[id] {
            return try diagnostics.measurePipelineCompile(
                pipelineID: id,
                wasCacheHit: true
            ) {
                existingState
            }
        }

        return try diagnostics.measurePipelineCompile(
            pipelineID: id,
            wasCacheHit: false
        ) {

        let vertexFunctionName: String
        let fragmentFunctionName: String
        let pipelineLabel: String
        let colorPixelFormat: MTLPixelFormat

        switch id {
        case .modelPBR:
            vertexFunctionName = "modelVertex"
            fragmentFunctionName = "modelPBRFragment"
            pipelineLabel = "USD Model PBR Pipeline"
            colorPixelFormat = MetalRenderer.sceneColorPixelFormat

        case .modelNormalDiagnostic:
            vertexFunctionName = "modelVertex"
            fragmentFunctionName = "modelNormalDiagnosticFragment"
            pipelineLabel = "USD Model Normal Diagnostic Pipeline"
            colorPixelFormat = MetalRenderer.sceneColorPixelFormat

        case .hdrToneMappedPresentation:
            vertexFunctionName = "hdrPresentationVertex"
            fragmentFunctionName = "hdrToneMappedPresentationFragment"
            pipelineLabel = "HDR Tone-Mapped Presentation Pipeline"
            colorPixelFormat = MetalRenderer.colorPixelFormat

        case .linearPresentation:
            vertexFunctionName = "hdrPresentationVertex"
            fragmentFunctionName = "linearPresentationFragment"
            pipelineLabel = "Linear Diagnostic Presentation Pipeline"
            colorPixelFormat = MetalRenderer.colorPixelFormat
        }

        let library = try self.shaderLibrary(for: .engine)
        let vertexFunction = MTL4LibraryFunctionDescriptor()
        vertexFunction.library = library
        // Metal identifies shader entry points by their source names. The
        // closed pipeline identity above owns every externally required string
        // so arbitrary names cannot enter the draw path.
        vertexFunction.name = vertexFunctionName

        let fragmentFunction = MTL4LibraryFunctionDescriptor()
        fragmentFunction.library = library
        fragmentFunction.name = fragmentFunctionName

        let descriptor = MTL4RenderPipelineDescriptor()
        descriptor.label = pipelineLabel
        descriptor.vertexFunctionDescriptor = vertexFunction
        descriptor.fragmentFunctionDescriptor = fragmentFunction
        descriptor.rasterSampleCount = 1
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat

        let state = try self.compiler.makeRenderPipelineState(
            descriptor: descriptor
        )

            self.renderPipelineStates[id] = state
            return state
        }
    }

    /// Creates the immutable depth-stencil state defined by a closed identity.
    @discardableResult
    private func loadDepthStencilState(
        _ id: MetalDepthStencilStateID
    ) throws -> any MTLDepthStencilState {
        if let existingState = depthStencilStates[id] {
            return existingState
        }

        let descriptor = Self.makeDepthStencilDescriptor(for: id)

        guard let state = device.makeDepthStencilState(
            descriptor: descriptor
        ) else {
            throw MetalResourceStoreError.missingDepthStencilState(id)
        }

        depthStencilStates[id] = state
        return state
    }

    /// Builds the inspectable descriptor behind a cached depth-stencil state.
    ///
    /// `MTLDepthStencilState` intentionally does not expose the descriptor used
    /// to create it. Keeping this deterministic factory separate lets tests lock
    /// the ordinary opaque-depth convention without duplicating that policy.
    static func makeDepthStencilDescriptor(
        for id: MetalDepthStencilStateID
    ) -> MTLDepthStencilDescriptor {
        let descriptor = MTLDepthStencilDescriptor()

        switch id {
        case .opaque:
            descriptor.label = "Opaque Depth"
            descriptor.depthCompareFunction = .less
            descriptor.isDepthWriteEnabled = true
        }

        return descriptor
    }

    /// Creates the Metal 4 argument table defined by a closed identity.
    @discardableResult
    private func loadArgumentTable(
        _ id: MetalArgumentTableID
    ) throws -> any MTL4ArgumentTable {
        if let existingTable = argumentTables[id] {
            return existingTable
        }

        let descriptor = MTL4ArgumentTableDescriptor()

        switch id {
        case .model:
            descriptor.label = "USD Mesh Argument Table"
            descriptor.maxBufferBindCount = 2

        case .pbrScene:
            // The fragment function consumes the current per-draw instance at
            // buffer index 1 and the frame's light-only scene record at index
            // 2. Capacity includes the unused vertex-only index 0 as well.
            descriptor.label = "PBR Scene Argument Table"
            descriptor.maxBufferBindCount = 3

        case .hdrPresentation:
            descriptor.label = "HDR Presentation Argument Table"
            descriptor.maxBufferBindCount = 1
            descriptor.maxTextureBindCount = 1
        }

        let table = try device.makeArgumentTable(descriptor: descriptor)

        argumentTables[id] = table
        return table
    }

    /// Creates a fixed ring of per-frame allocators and mutable buffers.
    ///
    /// Separate resources let the CPU encode a later frame while the GPU still
    /// consumes an earlier one without resetting command memory or overwriting
    /// instance data in use. The bounded ring applies back pressure rather than
    /// allocating an unbounded stream of transient frame resources.
    private func makeFrameResources(count: Int) throws {
        for _ in 0..<count {
            guard let commandAllocator = device.makeCommandAllocator(),
                  let instanceBuffer = device.makeBuffer(
                    length: MemoryLayout<GPUInstance>.stride
                        * FrameResources.maximumInstanceCount,
                    options: [.storageModeShared]
                  ),
                  let pbrSceneParametersBuffer = device.makeBuffer(
                    length: MemoryLayout<PBRSceneParameters>.stride,
                    options: [.storageModeShared]
                  ),
                  let hdrPresentationParametersBuffer = device.makeBuffer(
                    length: MemoryLayout<HDRPresentationParameters>.stride,
                    options: [.storageModeShared]
                  )
            else {
                throw MetalResourceStoreError.missingFrameResource
            }

            for allocation in [
                instanceBuffer as any MTLAllocation,
                pbrSceneParametersBuffer as any MTLAllocation,
                hdrPresentationParametersBuffer as any MTLAllocation
            ] {
                residency.addFrameAllocation(allocation)
            }
            frames.append(
                FrameResources(
                    commandAllocator: commandAllocator,
                    instanceBuffer: instanceBuffer,
                    pbrSceneParametersBuffer: pbrSceneParametersBuffer,
                    hdrPresentationParametersBuffer: hdrPresentationParametersBuffer
                )
            )
        }

        // One commit makes every buffer in the completed frame ring visible to
        // queue submissions that reference the frame residency set.
        residency.commitFrameResources()
    }

    private func loadModels(from catalog: RenderAssetCatalog) throws {
        _ = try diagnostics.measureAssetLoad(requestedModelCount: catalog.models.count) {
            let loadedModels = try USDRenderModel.load(
                catalog: catalog,
                device: self.device
            )

            for (meshID, model) in loadedModels {
                self.models[meshID] = model

                for allocation in model.allocations {
                    self.residency.addStaticAllocation(allocation)
                }
            }

            // Apply the full initial asset batch together. Later streaming can use
            // the same add/commit boundary without changing snapshot contracts.
            self.residency.commitStaticAssets()
            let meshCount = loadedModels.values.reduce(0) { $0 + $1.meshes.count }
            let submeshCount = loadedModels.values.reduce(0) { count, model in
                count + model.meshes.reduce(0) { $0 + $1.submeshes.count }
            }
            return RenderAssetLoadCounts(
                loadedModelCount: loadedModels.count,
                meshCount: meshCount,
                submeshCount: submeshCount
            )
        }
    }

    /// Publishes one completed low-frequency inventory after construction.
    private func reportResourceInventory() {
        let meshCount = models.values.reduce(0) { $0 + $1.meshes.count }
        let submeshCount = models.values.reduce(0) { count, model in
            count + model.meshes.reduce(0) { $0 + $1.submeshes.count }
        }
        diagnostics.recordRenderResourceInventory(
            RenderResourceInventoryDiagnostics(
                modelCount: models.count,
                meshCount: meshCount,
                submeshCount: submeshCount,
                pipelineCount: renderPipelineStates.count,
                argumentTableCount: argumentTables.count,
                materialCount: materialDescriptions.count,
                frameResourceCount: frames.count
            )
        )
    }
}
