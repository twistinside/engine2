/// CPU-prepared Metal input for one immutable render frame.
///
/// Each bounded instance carries its already-resolved material and optional
/// model beside it, so GPU packing and ordered drawing cannot drift across
/// parallel arrays or a second resource lookup. Preparing this value resolves
/// all authored content before a caller resets allocators, writes GPU buffers,
/// or begins a Metal 4 command buffer. Exact callers validate these retained
/// optional model values before encoding; the live screen may omit a missing
/// model while continuing to present later frames.
struct MetalPreparedFrame {
    let renderFrame: RenderFrame

    /// Ordinary opaque PBR draws retained in source order.
    let instances: [(
        renderInstance: RenderInstance,
        materialDescription: PBRMaterialDescription,
        model: USDRenderModel?
    )]

    /// Layered planet draws retained in source order.
    let terrestrialPlanetInstances: [
        MetalPreparedTerrestrialPlanetInstance
    ]

    /// Total Simulation identities admitted to this bounded prepared frame.
    var instanceCount: Int {
        instances.count + terrestrialPlanetInstances.count
    }

    /// Resolves the exact prefix writable by one reusable frame slot.
    init(renderFrame: RenderFrame, resources: MetalResourceStore) {
        self.renderFrame = renderFrame

        var instances: [(
            renderInstance: RenderInstance,
            materialDescription: PBRMaterialDescription,
            model: USDRenderModel?
        )] = []
        var terrestrialPlanetInstances: [
            MetalPreparedTerrestrialPlanetInstance
        ] = []

        for instance in renderFrame.instances.prefix(
            FrameResources.maximumInstanceCount
        ) {
            switch resources.renderMaterialDescription(
                for: instance.materialID
            ) {
            case let .opaquePBR(description):
                instances.append((
                    renderInstance: instance,
                    materialDescription: description,
                    model: resources.model(for: instance.meshID)
                ))

            case let .terrestrialPlanet(description):
                guard let planetResources = resources
                    .terrestrialPlanetResources(for: instance.materialID)
                else {
                    preconditionFailure(
                        "Resource-store construction must resolve every terrestrial-planet appearance."
                    )
                }
                terrestrialPlanetInstances.append(
                    MetalPreparedTerrestrialPlanetInstance(
                        renderInstance: instance,
                        description: description,
                        resources: planetResources,
                        model: resources.model(for: instance.meshID)
                    )
                )
            }
        }

        self.instances = instances
        self.terrestrialPlanetInstances = terrestrialPlanetInstances
    }
}
