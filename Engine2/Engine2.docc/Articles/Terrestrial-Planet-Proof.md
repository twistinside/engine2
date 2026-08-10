# Terrestrial Planet Proof

The terrestrial-planet proof renders one authoritative Simulation entity as a
procedurally surfaced, layered orbital-scale body. Game Content owns the entity,
typed identities, and one deterministic surface recipe. Render generates and
owns the sampled maps, pipelines, GPU records, residency, and ordered draw work.

## Scene and Authority

`BasicGameContent.init()` selects `TerrestrialPlanetWorldBuilder`, which creates
one ``TerrestrialPlanet`` at the origin under a narrow-field proof camera. The
entity owns one authoritative transform and registers `MeshID.ball` with
`MaterialID.terrestrialPlanet`. The planet reuses the generic `Ball.usdz` sphere;
it has no planet-specific model asset. ``World`` and
``SimulationPresentationSnapshot`` continue to publish one entity rather than
separate terrain, ocean, cloud, or atmosphere entities.

`BasicWorldBuilder` remains the deterministic six-sphere opaque-PBR fixture. A
test or specialized host can select it through
`BasicGameContent.init(worldBuilder:)`, but it is no longer the App's default
scene.

The planet's uniform scale of `2.5` and distant 23-degree camera approximate the
compressed full-disk composition of Apollo 17 frame `AS17-148-22727`. Its
authored rotation centers southern Africa, keeps Arabia near the upper limb,
places Madagascar to the east, and exposes Antarctica. Rotation, scale, and
camera remain Simulation-owned state. The surface recipe and layer parameters
remain immutable catalog data.

The iconic processed square presentation of the Apollo photograph is the visual
target, not a texture source. The implementation consumes no pixels or map data
from the photograph. The recipe instead drives deterministic continent, coast,
terrain, biome, ice, and weather generation so other viewpoints remain
coherent.

## Game Content Supplies a Recipe

``TerrestrialPlanetDescription`` distinguishes the procedural planet material
from ordinary opaque PBR material data. Game Content supplies one
``TerrestrialPlanetSurfaceRecipe`` together with normalized local-space surface,
cloud, and atmosphere parameters. The `.blueMarble` recipe selects the current
proof appearance with seed `0x45415254` and normal relief `0.006`. Normal relief
controls height-to-normal conversion only; it does not change the sphere's
radius.

The recipe is backend-neutral construction input. It does not contain decoded
pixels, a Metal texture, or executable renderer work. Game Content checks in no
planet PNG, USD, manifest, or Python generator. Its catalog resolves only the
generic sphere model and the material descriptions needed by the selected
scene.

## Render Generates the Sampled Maps Once

During `MetalResourceStore` construction, Render deterministically expands each
planet recipe into four 1024×512 equirectangular maps:

- The linear RGBA8 normal map stores tangent-space east, south, and radial
  components in RGB with opaque alpha. Ocean normals remain radial, and tangent
  components fade near the poles where the basis becomes unstable.
- The sRGB RGBA8 surface map stores ocean, land, vegetation, rock, desert, and
  ice color in RGB plus a binary land mask in alpha.
- The linear RGBA8 control map stores moisture, vegetation, ice, and perceptual
  roughness.
- The linear RGBA8 cloud map stores coverage, density, detail, and repeated
  coverage used by both the cloud shell and the surface cloud-shadow
  approximation.

Generation first builds a temporary scalar height field. Render uses neighboring
height samples to derive the tangent-space normal map, then discards height as a
construction intermediate. Height never displaces a surface vertex. This keeps
the planetary silhouette at the exact authored surface radius while normals
provide orbital-scale terrain lighting detail.

``TerrestrialPlanetSurfaceGenerator`` returns detached base-level RGBA8 bytes.
Production generation uses the fixed 2:1 dimensions above; smaller injectable
2:1 dimensions support focused tests. The `.blueMarble` production value is a
thread-safe immutable cache, so the process computes those bytes once and each
device-scoped resource store can reuse them.

``MetalTerrestrialPlanetTextureBuilder`` constructs every mip level on the CPU,
including the final 1×1 level, and writes the complete chains into shared-storage
Metal textures. The normal chain renormalizes each filtered direction, surface
RGB filtering occurs in linear light before sRGB encoding, and linear control
and cloud levels use box filtering. The textures receive no mutation after
construction. ``MetalTerrestrialPlanetResources`` retains them for the lifetime
of its device-scoped resource store. ``MetalResidencyManager`` adds their
allocations to the queue-wide static-asset residency set before its single
construction-time commit. Every planet draw and frame in that store reuses the
same texture objects; generation does not run at presentation cadence.

## One Entity Expands Into Ordered Render Work

``MetalPreparedFrame`` resolves the material family before mutable frame work
begins. One planet becomes one `MetalPreparedTerrestrialPlanetInstance` that
retains its model, authored description, and generated map set. The value
remains one-to-one with the Simulation entity even though ``MetalFrameEncoder``
reuses its mesh and transform for three ordered draws inside the same HDR scene
render encoder:

1. The opaque surface draw keeps every vertex at the fixed surface radius. Its
   fragment shader blends the generated tangent-space normal with the radial
   sphere normal, samples generated color and roughness, and shades ocean,
   vegetation, ice, and mountains through the shared direct-light PBR function.
   It writes depth.
2. The cloud-shell draw samples the generated cloud map, contributes
   premultiplied color and alpha, tests the opaque depth buffer, and does not
   write depth. The surface shader also projects that coverage toward the fixed
   light to darken the surface beneath clouds.
3. The atmosphere-shell draw contributes opacity-weighted additive scattering
   after the clouds. It tests but does not write depth.

The shared HDR presentation pass then applies the caller's existing output
policy. The normal diagnostic draws only the opaque planet surface and reports
the same normal blend used by surface lighting; it does not composite clouds or
atmosphere into a normal field.

## Screen and Exact Output Share the Encoder

The MetalKit screen adapter and ``MetalOffscreenRenderRuntime`` both use the
same ``MetalFrameEncoder``, procedural resource construction, and planet
pipelines. The screen keeps its existing latest-presentation and drawable
policy. The exact path keeps its explicit snapshot, viewpoint, limits, one-slot
resources, queue-feedback lifetime, and readback semantics. The planet does not
introduce a second screen-only or offscreen-only shading path. Each caller owns
its device-scoped resource store. Those stores request the same cached
procedural bytes and construct equivalent Metal resources.

The production offscreen regression measures broad image semantics instead of
comparing against NASA pixels or a GPU-specific golden image. It bounds the
disk framing, ocean and land color populations, display-space contrast,
Africa-region land, oceans on both sides of the continent, and bright southern
weather. The southern bright-neutral population must exceed the northern
population, preserving the target's defining Southern Hemisphere cloud bias.

Render has no planet clock. Generated maps, atmosphere, and proof lighting are
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
of `(1, 0.99, 0.96)`. The ordinary PBR proof scene keeps its existing warm
validation color.

This light is a controlled renderer input, not a semantic star in Game Content,
an ECS entity, or a value published by Simulation. Introducing stars, eclipses,
or gameplay-visible illumination requires a deliberate semantic light boundary
rather than another renderer constant.

## Current Limits

- The proof uses normalized orbital scale. A unit-radius surface plus the
  entity's display scale does not represent kilometers or a general celestial
  coordinate model.
- The generic sphere has no level of detail, tessellation policy, terrain patch
  selection, or asset streaming.
- Normal-only relief changes lighting but not the planet's silhouette, depth,
  self-shadowing, parallax, or occlusion. A near-surface camera requires a
  separate geometry level-of-detail design rather than global globe
  tessellation.
- The current camera and surface treatment target an orbital view, not a
  ground-level view or landing transition.
- The planet path uses a finite, positive uniform entity scale. Nonuniform and
  mirrored planet transforms are outside this proof's shading and culling
  contract.
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
