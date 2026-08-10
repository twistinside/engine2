import Metal

/// Device-scoped owner for long-lived Metal backend objects.
///
/// The store is private infrastructure inside a Render Runtime. Game Content
/// supplies backend-neutral asset references, while this object resolves and
/// retains the corresponding device objects for exactly one `MTLDevice`.
final class MetalResourceStore {
    /// Default number of reusable allocator/buffer slots for live rendering.
    static let defaultFrameCount = 3

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

    /// Complete nonoptional built-in state resolved before the store is usable.
    let requiredResources: MetalRequiredResources

    /// Fixed ring of allocator/buffer pairs used by the renderer.
    private(set) var frames: [FrameResources] = []

    private var models: [MeshID: USDRenderModel] = [:]

    private var terrestrialPlanetResources: [
        MaterialID: MetalTerrestrialPlanetResources
    ] = [:]

    /// Validated authored descriptions retained as CPU-side Render resources.
    ///
    /// The current material count does not justify a separate GPU table. Each
    /// frame resolves these values into its existing per-draw instance records,
    /// while this dictionary preserves the Game Content identity boundary.
    private let materialDescriptions: [
        MaterialID: PBRMaterialDescription
    ]

    private let terrestrialPlanetDescriptions: [
        MaterialID: TerrestrialPlanetDescription
    ]

    /// Selects the system's default Metal device and creates a complete store
    /// containing the renderer's required built-in resources.
    convenience init(renderAssetCatalog: RenderAssetCatalog, frameCount: Int) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalResourceStoreError.missingDevice
        }

        try self.init(
            device: device,
            renderAssetCatalog: renderAssetCatalog,
            frameCount: frameCount
        )
    }

    /// Creates a resource store for an explicitly selected device.
    init(device: any MTLDevice, renderAssetCatalog: RenderAssetCatalog, frameCount: Int) throws {
        guard frameCount > 0 else {
            throw MetalResourceStoreError.invalidFrameCount(frameCount)
        }

        // Validate the closed authored-material vocabulary before allocating or
        // compiling backend state. A malformed content package therefore fails
        // during Render Runtime construction, never halfway through a frame.
        try renderAssetCatalog.validateMaterialCoverage()

        guard let commandQueue = device.makeMTL4CommandQueue() else {
            throw MetalResourceStoreError.missingCommandQueue
        }

        let compilerDescriptor = MTL4CompilerDescriptor()
        compilerDescriptor.label = "Engine2 Render Compiler"
        let compiler = try device.makeCompiler(descriptor: compilerDescriptor)

        let residency = try MetalResidencyManager(
            device: device,
            commandQueue: commandQueue,
            staticAssetCapacity: max(
                renderAssetCatalog.models.count * 4
                    + renderAssetCatalog.terrestrialPlanets.count * 4,
                1
            ),
            frameResourceCapacity: frameCount * 4
        )
        let requiredResources = try MetalRequiredResources(
            device: device,
            compiler: compiler
        )

        self.device = device
        self.compiler = compiler
        self.commandQueue = commandQueue
        self.residency = residency
        self.requiredResources = requiredResources
        self.materialDescriptions = renderAssetCatalog.materials
        self.terrestrialPlanetDescriptions = renderAssetCatalog
            .terrestrialPlanets

        // Construction has already proved the complete fixed resource set.
        // Dynamic frame allocations and optional catalog models keep their
        // separate lifetime and availability contracts.
        try makeFrameResources(count: frameCount)
        try loadStaticAssets(from: renderAssetCatalog)
    }

    /// Resolves an abstract snapshot mesh identity to a retained backend model.
    func model(for id: MeshID) -> USDRenderModel? {
        models[id]
    }

    /// Resolves one identity to the authored material family Render supports.
    func renderMaterialDescription(for id: MaterialID) -> RenderMaterialDescription {
        if let description = materialDescriptions[id] {
            return .opaquePBR(description)
        }

        // Complete, exclusive coverage was proved during construction.
        return .terrestrialPlanet(terrestrialPlanetDescriptions[id]!)
    }

    /// Returns the retained generated GPU maps for one terrestrial-planet material.
    func terrestrialPlanetResources(
        for id: MaterialID
    ) -> MetalTerrestrialPlanetResources? {
        terrestrialPlanetResources[id]
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
                  let terrestrialPlanetInstanceBuffer = device.makeBuffer(
                    length: MemoryLayout<GPUPlanetInstance>.stride
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
                terrestrialPlanetInstanceBuffer as any MTLAllocation,
                pbrSceneParametersBuffer as any MTLAllocation,
                hdrPresentationParametersBuffer as any MTLAllocation
            ] {
                residency.addFrameAllocation(allocation)
            }
            let frame = FrameResources(
                commandAllocator: commandAllocator,
                instanceBuffer: instanceBuffer,
                terrestrialPlanetInstanceBuffer: terrestrialPlanetInstanceBuffer,
                pbrSceneParametersBuffer: pbrSceneParametersBuffer,
                hdrPresentationParametersBuffer: hdrPresentationParametersBuffer
            )
            frames.append(frame)
        }

        // One commit makes every buffer in the completed frame ring visible to
        // queue submissions that reference the frame residency set.
        residency.commitFrameResources()
    }

    private func loadStaticAssets(from catalog: RenderAssetCatalog) throws {
        try loadModels(from: catalog)
        try resolveTerrestrialPlanets(from: catalog)

        // Apply the complete initial asset batch together. Later streaming can
        // use the same add/commit boundary without changing snapshot contracts.
        residency.commitStaticAssets()
    }

    private func loadModels(from catalog: RenderAssetCatalog) throws {
        let loadedModels = try USDRenderModel.load(
            catalog: catalog,
            device: device
        )

        for (meshID, model) in loadedModels {
            models[meshID] = model

            for allocation in model.allocations {
                residency.addStaticAllocation(allocation)
            }
        }
    }

    private func resolveTerrestrialPlanets(
        from catalog: RenderAssetCatalog
    ) throws {
        for (materialID, description) in catalog.terrestrialPlanets {
            let resources = try MetalTerrestrialPlanetResources(
                description: description,
                device: device
            )
            terrestrialPlanetResources[materialID] = resources

            for allocation in resources.allocations {
                residency.addStaticAllocation(allocation)
            }
        }
    }
}
