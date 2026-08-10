# Terrestrial Planet Proof

The terrestrial-planet proof renders one authoritative Simulation entity as a
layered orbital-scale body. Game Content owns the entity, typed identities,
descriptions, and checked-in source assets. Render privately owns decoded
textures, pipelines, GPU records, residency, and ordered draw work.

## Scene and Authority

`BasicGameContent.init()` selects `TerrestrialPlanetWorldBuilder`, which creates
one ``TerrestrialPlanet`` at the origin under an authored narrow-field proof
camera. The entity owns one authoritative transform and registers one
backend-neutral `MeshID` and `MaterialID`. ``World`` and
``SimulationPresentationSnapshot`` continue to publish one entity; they do not
contain separate terrain, ocean, cloud, or atmosphere entities.

`BasicWorldBuilder` remains the deterministic six-sphere opaque-PBR fixture. A
test or specialized host can select it through
`BasicGameContent.init(worldBuilder:)`, but it is no longer the App's default
scene.

The planet's uniform scale of `2.5` and distant 23-degree camera approximate the
compressed full-disk composition of Apollo 17 frame `AS17-148-22727`. Its
authored rotation centers southern Africa, keeps Arabia near the upper limb,
places Madagascar to the east, and exposes Antarctica. Rotation, scale, and
camera remain Simulation-owned state. The authored maps and layer parameters
remain immutable catalog data.

The iconic processed square presentation of the Apollo photograph is a visual
target, not a texture source. The generator consumes no pixels or map data from
the photograph. It uses coarse hand-authored continental silhouettes and
procedural coast, terrain, biome, ice, and weather detail so other viewpoints
remain coherent.

## Authored Assets

The proof checks in four deterministic 1024×512 equirectangular maps under
`Engine2/Game Content/Planet/Assets/`:

- `TerrestrialPlanetElevation.png` stores 16-bit linear height. Sample 32768 is
  sea level; lower samples represent ocean depth and higher samples represent
  land elevation.
- `TerrestrialPlanetSurface.png` stores sRGB surface color in RGB and a binary
  land mask in alpha.
- `TerrestrialPlanetControl.png` stores linear moisture, vegetation, ice or
  snow, and perceptual roughness in RGBA order.
- `TerrestrialPlanetClouds.png` stores linear coverage, density, detail, and
  repeated coverage in RGBA order.

The checked-in `TerrestrialPlanet.usdz` contains a generated unit-radius
256×128 UV sphere. Its 33,153 vertices and 65,536 triangles provide enough
geometry for the current vertex-stage terrain displacement. The accompanying
`TerrestrialPlanet.usda` is the readable source layer, and
`TerrestrialPlanetManifest.json` records the generator version, seed, channel
contracts, content metrics, dimensions, and SHA-256 digests.
Global surface fractions use cosine-latitude weighting so the equirectangular
rows near each pole do not overstate their share of the sphere.

`BasicGameContentResources` is the only content boundary that searches the
current application bundle. It gives ``ModelAssetReference`` and
``TextureAssetReference`` exact file URLs. Each texture reference also declares
its ``TextureAssetInterpretation`` as `.sRGB` color or `.linear` data. Render
therefore does not infer transfer functions from a filename or search a bundle
while loading an asset.

``RenderAssetCatalog`` validates exclusive material-family coverage and the
texture identities required by each ``TerrestrialPlanetDescription`` before
the resource store allocates backend state. ``MetalTextureAssetLoader`` decodes
the exact references into private shader-read textures and generates their mip
chains. ``MetalTerrestrialPlanetResources`` then proves that all four maps have
the required dimensions, mip counts, channel precision, and transfer-function
formats. MetalKit may choose RGBA or BGRA byte order for the three four-channel
maps; both preserve the same shader-visible channel order.

## One Entity Expands Into Ordered Render Work

``RenderMaterialDescription`` distinguishes ordinary opaque PBR material data
from one layered ``TerrestrialPlanetDescription``. The distinction remains
Render-owned; Simulation still carries only the entity's mesh and material
identities.

``MetalPreparedFrame`` resolves the material family before mutable frame work
begins. One planet becomes one `MetalPreparedTerrestrialPlanetInstance` that
retains its model, authored description, and resolved map set. The value remains
one-to-one with the Simulation entity even though ``MetalFrameEncoder`` reuses
its mesh and transform for three ordered draws inside the same HDR scene render
encoder:

1. The opaque surface draw keeps ocean at the base radius, displaces land from
   the elevation map, derives terrain normals from neighboring samples, and
   shades ocean, vegetation, ice, and mountains through the shared direct-light
   PBR function. It writes depth.
2. The cloud-shell draw samples the static cloud map, contributes
   premultiplied color and alpha, tests the opaque depth buffer, and does not
   write depth. The surface shader also projects that coverage toward the fixed
   light to darken the surface beneath clouds.
3. The atmosphere-shell draw contributes opacity-weighted additive scattering
   after the clouds. It tests but does not write depth.

The shared HDR presentation pass then applies the caller's existing output
policy. The normal diagnostic draws only the displaced opaque planet surface;
it does not composite clouds or atmosphere into a normal field.

## Screen and Exact Output Share the Encoder

The MetalKit screen adapter and ``MetalOffscreenRenderRuntime`` both use the
same ``MetalFrameEncoder`` and planet pipelines. The screen keeps its existing
latest-presentation and drawable policy. The exact path keeps its explicit
snapshot, viewpoint, limits, one-slot resources, queue-feedback lifetime, and
readback semantics. The planet does not introduce a second screen-only or
offscreen-only shading path.

The production offscreen regression measures broad image semantics instead of
comparing against NASA pixels or a GPU-specific golden image. It bounds the
disk framing, ocean and land color populations, display-space contrast,
Africa-region land, oceans on both sides of the continent, and bright southern
weather. The southern bright-neutral population must exceed the northern
population, preserving the target's defining Southern Hemisphere cloud bias.

``MetalResourceStore`` retains the decoded sphere and four immutable textures.
Their allocations enter the queue-wide static-asset residency set before its
single construction-time commit. Each frame slot adds its
`GPUPlanetInstance` buffer to the committed frame-resource set, while the
existing caller-owned target residency remains unchanged.

Render has no planet clock. The cloud map, atmosphere, and proof lighting are
pure functions of the immutable catalog, selected snapshot, selected camera,
and output settings. A future independently rotating cloud layer must enter as
explicit Simulation-owned presentation state rather than sampled Render wall
time so screen and exact output remain reproducible.

## Fixed Proof Sun

The current planet uses one renderer-owned proof sun. `GPUPlanetInstance`
derives its view- and model-local directions from the normalized world-space
vector `(0.08, 0.10, 0.99)`. The nearly camera-aligned direction produces the
full-phase appearance of the Apollo target without a localized ocean glint. It
uses the shared fixed frame-light intensity of `8` with a neutral daylight tint
of `(1, 0.99, 0.96)`. The ordinary PBR proof
scene keeps its existing warm validation color.

This light is a controlled renderer input, not a semantic star in Game Content,
an ECS entity, or a value published by Simulation. Introducing stars, eclipses,
or gameplay-visible illumination requires a deliberate semantic light boundary
rather than another renderer constant.

## Rebuild and Validate the Assets

The deterministic generator is
`Tools/PlanetAssetGenerator/generate_planet_assets.py`. It requires Python 3 and
no third-party packages. Run it from the repository root to replace the
checked-in source assets and manifest:

```sh
python3 Tools/PlanetAssetGenerator/generate_planet_assets.py
```

Validate the checked-in files without modifying them:

```sh
python3 Tools/PlanetAssetGenerator/generate_planet_assets.py --check
```

The check recooks the complete output in a temporary directory and compares
every generated byte with the checked-in files. It also covers manifest
digests, PNG dimensions and channel formats, decoded scanline layout,
longitude continuity, content metrics, USDZ storage and alignment, and equality
between the USDA source and packaged layer.

## Current Limits

- The proof uses normalized orbital scale. A unit-radius surface plus the
  entity's display scale does not represent kilometers or a general celestial
  coordinate model.
- The single dense sphere has no level of detail, tessellation policy, terrain
  patch selection, or asset streaming.
- The current camera and displacement are intended for an orbital view, not a
  ground-level view or landing transition.
- The authored planet path uses a finite, positive uniform entity scale.
  Nonuniform and mirrored planet transforms are outside this proof's shading
  and culling contract.
- Clouds are a static translucent shell. The proof has no volumetric weather,
  evolving coverage, precipitation, or Simulation-owned cloud motion.
- Layer ordering targets the current single planet. Render does not yet sort
  translucent shells across several planets or other transparent geometry.
- The fixed proof sun is not a semantic star, light source, orbit, eclipse, or
  shadowing relationship in Simulation.
- The atmosphere is a stylized shell approximation. It is not physically exact
  spectral or multiple-scattering atmosphere simulation.

## Related Architecture

- <doc:Rendering-Architecture>
- <doc:Game-Content-Architecture>
- <doc:Runtime-Communication>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
