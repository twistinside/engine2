/// Fully resolved Render input for one terrestrial-planet entity.
///
/// One Simulation-owned identity remains one value here. The frame encoder
/// privately reuses its mesh and transform for the ordered opaque surface,
/// cloud-shell, and atmosphere draws.
struct MetalPreparedTerrestrialPlanetInstance {
    let renderInstance: RenderInstance
    let description: TerrestrialPlanetDescription
    let resources: MetalTerrestrialPlanetResources
    let model: USDRenderModel?
}
