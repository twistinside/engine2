# PBR Implementation Plan

This article defines the smallest explainable path from Engine2's former
vertex-color bootstrap renderer to a direct-light physically based material
renderer. It also identifies where the already-chosen Forward+ light-selection
work begins.

## Status

The PBR bootstrap is implemented. Milestones 1–5 now establish the complete
authored-material validation path; Forward+ light assignment remains a later
scaling project.

The visible renderer now resolves authored Game Content materials, evaluates
the same direct-light BRDF as the isolated proof, writes scene-linear radiance
into a renderer-owned half-float target, and presents it through explicit
exposure, Reinhard tone mapping, and one sRGB transfer. Its directional light
remains a fixed Render-owned validation input. A deterministic six-sphere scene
exercises the ordinary Game Content-to-Simulation-to-Render path; semantic
lighting is not yet a Simulation or snapshot concept.

The production PBR/HDR encoding path now lives in view-independent
``MetalFrameEncoder``. A render integration test drives that encoder through
caller-owned offscreen textures, residency, queue feedback, and readback with
no view or drawable. This validates reuse of the production path, but it does
not establish a production offscreen request API, artifact/JPEG pipeline, or
asynchronous Render worker.

The plan deliberately stops short of specifying the eventual renderer in full.
Each milestone introduces one observable capability and must leave the engine
working without code from the next milestone.

## First Baseline

The first PBR baseline is intentionally narrow:

- opaque geometry
- base color, metallic, and perceptual roughness factors
- Lambert diffuse
- GGX distribution, Smith visibility, and Schlick Fresnel
- one Render-owned directional light
- linear RGB lighting
- depth-correct drawing
- HDR scene color followed by explicit exposure and tone mapping

Textures, emission, image-based lighting, shadows, and semantic light state are
not required to prove this baseline.

PBR and Forward+ solve different problems. The baseline first proves the
material math and the complete render pathway under one global directional
light. A directional light affects every visible surface, so assigning it to
screen tiles would add machinery without testing local-light selection.
Forward+ later changes how Render selects local lights for each fragment; it
does not introduce a second BRDF or another selectable render path.

## Conventions Required Up Front

Only conventions consumed by the first milestones are fixed now:

- CPU and Metal matrix order and handedness must agree.
- Lighting vectors and surface positions are evaluated in one documented
  coordinate space; view space is the initial choice.
- Normals use the inverse transpose of the model-view transform and are
  normalized after interpolation.
- Material and light calculations use finite linear RGB values.
- Base color, metallic, and roughness have documented legal ranges.
- The validation light uses one documented, normalized world-space direction
  that Render transforms into the BRDF's working space.
- The BRDF equations are written once and shared by proof and production
  shading.

The validation light's color, intensity, and exposure are scene-linear controls,
not a claim of physical calibration. Physical light units and a physical camera
require a separate decision when representative content needs them.

## Ownership

### Game Content

Game Content owns the identities, authored description values, and packaged
assets that make the game distinct. It populates Render-owned backend-neutral
catalog contracts but never owns decoded Metal resources.

The validation scene reuses one sphere mesh for several material examples. Game
Content therefore owns a strongly typed `MaterialID` as well as `MeshID`; the
engine must not invent duplicate mesh identities or decode the same geometry
multiple times to distinguish materials.

### Simulation Runtime

Simulation remains authoritative for semantic world state:

- `CRenderable` stores `MeshID` and `MaterialID`. Snapshot capture iterates that
  store and joins position, rotation, and scale from their separate components.
- The validation spheres are ordinary renderable entities. This plan adds no
  light component, light capability, or light array to the presentation
  snapshot.

The single validation light is deliberately not Simulation state. It is a
fixed Render configuration used to prove the render pathway. Semantic gameplay
lights require their own later ownership and snapshot design.

### Render Runtime

Render owns:

- decoded vertex and index buffers
- material GPU representations
- the fixed directional-light validation input
- depth and HDR targets
- Metal pipelines, argument tables, synchronization, and residency
- the eventual Forward+ light-assignment data

No Metal object, tile index, GPU address, or renderer capacity enters ECS or a
Simulation-owned snapshot.

## Milestone 1: Normals and Depth

### Outcome

The renderer can draw trustworthy, depth-correct opaque geometry before any
lighting equation is involved.

### Change

- Extend the decoded vertex input to position, display color, and normal.
- Preserve decoded normals. The packaged polygonal sphere authors smooth outward
  normals with its explicit geometry; Model I/O carries them into the renderer's
  vertex layout without introducing a general runtime normal-generation policy.
- Provide view-space surface position and a correct normal transform to the
  fragment stage.
- Make perspective and orthographic projections share one ordinary depth
  convention: the near plane maps to `0`, the far plane maps to `1`, the depth
  attachment clears to `1`, and nearer fragments pass `.less`.
- Add the `depth32Float` attachment and matching depth state. Reversed-Z remains
  a separate precision change rather than being bundled with PBR.
- Add a normal diagnostic output.

### Checks

- A nonuniformly scaled sphere has correct normals.
- Overlapping geometry produces the same visible result regardless of draw
  order.
- Perspective and orthographic near/far test objects resolve in the same order.
- The normal diagnostic remains stable while the camera moves.

## Milestone 2: Isolated BRDF Proof

### Outcome

The metallic-roughness equations are proven without first redesigning Game
Content, Simulation, the drawable path, or the final GPU binding layout.

### Change

- Render a controlled sphere into a small offscreen `rgba16Float` target.
- Supply one renderer-owned constant material and directional light.
- Implement the shared direct-light BRDF in `float` precision:
  Lambert diffuse, GGX distribution, Smith visibility, and Schlick Fresnel.
- Use base color, metallic, and perceptual roughness factors only.
- Add diagnostic outputs for normal, base color, metallic, roughness,
  `N dot L`, diffuse, and specular contributions.

The proof may use a small test-only shader entry point or binding layout. The
durable requirement is one shared BRDF implementation, not guessing the final
argument-table ABI before material and light data exist.

### Checks

- Dielectric and metallic spheres at several roughness values behave
  predictably.
- Metallic response removes diffuse reflection.
- Increasing roughness broadens the specular response.
- Grazing-angle inputs remain finite.
- The offscreen target contains linear values rather than gamma-encoded color.

### Implemented Conventions

The proof deliberately fixes its mathematical vocabulary without treating its
test binding as a production ABI:

- `N`, `V`, and `L` are normalized view-space directions that point away from
  the surface: `N` is the surface normal, `V` points toward the camera, and `L`
  points toward the light source.
- Base color is finite linear RGB in `0...1`; metallic and input perceptual
  roughness are finite scalar factors in `0...1`; incident radiance is finite,
  nonnegative linear RGB.
- Evaluation floors perceptual roughness at `0.089`, then maps it to GGX
  `alpha` by squaring it. This keeps the direct-light proof finite at the
  zero input endpoint and makes the effective value visible through the
  roughness diagnostic.
- GGX normal distribution, height-correlated Smith visibility, and Schlick
  Fresnel are evaluated once in `PBRDirectLighting.metalh`. The Smith term
  already contains `G / (4 (N dot V) (N dot L))`; shading does not divide by a
  second Cook-Torrance denominator.
- Dielectric `F0` is `0.04`. Metallic blends `F0` toward base color and removes
  diffuse color. Lambert diffuse is weighted by both `1 - metallic` and
  `1 - Fresnel`.
- Both diffuse and specular direct-light contributions multiply incident
  radiance and saturated `N dot L` in the shared evaluator.

The proof shader draws an analytic front hemisphere with an orthographic camera
into a `65 x 65` `rgba16Float` target. Separate fragment entry points expose the
shaded result and each diagnostic, but all of them call the same evaluator. A
small four-`float4` parameter record and its argument table belong only to the
test harness. Milestone 3 chose its visible-path bindings independently while
including the same BRDF implementation.

## Milestone 3: Visible HDR PBR

### Outcome

The application visibly renders the proof material through a correct linear HDR
presentation chain.

### Change

- Add a renderer-owned `rgba16Float` scene target.
- Draw the same proven BRDF into that target with the renderer-owned proof
  material and directional light.
- Add a presentation phase that applies explicit manual exposure and a simple,
  documented tone map, initially Reinhard `x / (1 + x)`.
- Write display-linear color to the existing sRGB drawable so transfer encoding
  happens once.
- Explicitly set the Metal view or layer content color space to sRGB so the
  presented image participates in color matching.
- Retain drawable-sized resources for the lifetime of their in-flight Metal 4
  work and synchronize the scene write before the presentation read.

This introduces two render phases, not two lighting paths. Metal 4 argument
tables, resource retention, and explicit barriers remain private Render
implementation details.

### Checks

- Values above display white survive the material phase and roll off in the
  presentation phase.
- The image is not gamma encoded twice.
- Resizing replaces targets without releasing resources still used by an
  in-flight command buffer.
- Metal completion feedback surfaces command errors.

### Implemented Conventions

The visible pathway deliberately fixes its presentation and lifetime behavior
before authored material identity is introduced:

- `PBRSceneParameters` carries a fixed base color of `(0.5, 0.25, 0.125)`,
  metallic `0`, and perceptual roughness `0.5`. Its directional light points
  from the surface toward world-space `+Z`, has linear color `(1, 0.5, 0.25)`,
  and uses validation intensity `8`. Render transforms the direction into view
  space once per frame; camera translation never enters that transformation.
- Each reusable `FrameResources` slot owns its parameter buffers and lazily
  owns one private, drawable-sized `rgba16Float` texture with
  `renderTarget` and `shaderRead` usage. A size change replaces that texture
  only after the slot's availability semaphore proves its preceding submission
  is complete.
- The HDR texture owns a committed residency set attached to the exact Metal 4
  command buffer that references it. `MetalInFlightSubmission` retains the
  exact target, drawable, depth texture, store, and frame slot through queue
  feedback; residency and Swift object lifetime remain separate concerns.
- The first encoder shades geometry and stores linear HDR scene color. A single
  fragment-to-fragment device barrier follows the scene draws and precedes the
  second encoder, which samples that texture for presentation.
- `ManualExposure.validation` is an explicit scene-linear multiplier of `1`.
  Surface presentation clamps invalid or negative input to black, applies
  `x / (1 + x)`, and returns display-linear RGB. It contains no `pow` or manual
  gamma operation.
- The drawable remains `bgra8Unorm_srgb`, and the Metal view declares the sRGB
  color space. The drawable store therefore performs the pathway's only sRGB
  transfer encoding. The normal diagnostic uses a separate linear presentation
  fragment so exposure and tone mapping do not alter its `0...1` meaning.
- Queue feedback records the underlying Metal error before making the frame
  slot reusable. A renderer with a recorded asynchronous error stops submitting
  additional work and exposes that error for App diagnostics.

For the front-facing validation case where `N`, `V`, and `L` are all `+Z`, the
shared BRDF produces scene-linear RGB approximately
`(1.62975, 0.509296, 0.178254)`. Storage in `rgba16Float` quantizes this to
`(1.62988, 0.509277, 0.178223)`, proving that a value above display white
survives the material phase. Exposure `1` and Reinhard map the stored value to
approximately `(0.619755, 0.337431, 0.151264)` before the drawable performs its
single transfer encoding.

## Milestone 4: Authored Material Boundary

### Outcome

A renderer-owned proof material is replaced by an authored Game Content
material without exposing Metal resources or unnecessary presentation state.

### Change

- Define the minimal Render-owned `PBRMaterialDescription` contract with base
  color, metallic, and roughness factors.
- Let Game Content define `MaterialID` and supply the example material
  descriptions through `RenderAssetCatalog`.
- Add `MaterialID` to `CRenderable`, renderable spawn seeding, snapshot capture,
  and `RenderInstance` so the shared sphere mesh can represent several material
  appearances.
- Resolve that description privately into whatever GPU representation is
  simplest at the current scale.
- Ignore embedded USD materials and `displayColor` once this explicit material
  is authoritative.
- Remove only the renderer-owned proof material after the authored value
  reproduces it.

Do not add a material buffer or compact GPU material indices until the current
material count or draw organization requires them.

### Checks

- Changing the authored factors changes the rendered surface.
- Missing referenced material content fails before drawing rather than silently
  falling back.
- Several entities share one decoded sphere mesh when their appearances differ.
- Material factors and Metal resources never enter ECS or a Simulation
  snapshot. Only `MaterialID` crosses that boundary.

### Implemented Conventions

The authored boundary remains deliberately smaller than a general material
system:

- Game Content owns the exhaustive `MaterialID` vocabulary. Its first two cases
  are `warmDielectric` and `goldMetal`; both reuse `MeshID.ball` and differ only
  by authored material intent.
- Render owns `PBRMaterialDescription`. It accepts finite scene-linear base
  color channels, metallic, and perceptual roughness in `0...1`, rejecting
  invalid authored content instead of clamping it. The shader still owns the
  documented roughness evaluation floor.
- `RenderAssetCatalog` maps every `MaterialID` to one description. Store
  construction validates exhaustive coverage in stable `MaterialID.allCases`
  order before allocating or compiling backend resources. There is no default
  material and therefore no partially drawn frame with a substituted surface.
  `MetalSceneView.Coordinator` retains a construction failure for App
  diagnostics instead of silently erasing it when no renderer is created.
- `CRenderable`, `EntityPresentationSnapshot`, and `RenderInstance` carry only
  `MaterialID`. They contain no factors, compact GPU indices, buffers, or Metal
  objects. Snapshot capture copies the identity by value, so a later ECS change
  cannot alter an already published presentation.
- `MetalResourceStore` retains the validated CPU descriptions. ``MetalRenderer``
  waits for a screen frame slot and samples the newest completed presentation;
  ``MetalFrameEncoder`` resolves the bounded submitted prefix before the caller
  resets, writes, or encodes mutable GPU state. The encoder then packs base
  color plus metallic and roughness into each draw's existing `GPUInstance`.
  The 208-byte record remains stable through the caller's frame-completion rule;
  no separate material allocation or residency set exists.
- `PBRSceneParameters` is now a 32-byte light-only record. Its fixed world-space
  directional light is transformed into view space once per frame, while the
  fragment stage reads the current draw's material from its instance record.
- The model shader does not consume the decoded vertex display color or any
  embedded USD material. The explicit authored description is the sole surface
  authority even though the transitional vertex lane remains in the decoded
  mesh layout.

`warmDielectric` preserves the Milestone 3 factors exactly: base color
`(0.5, 0.25, 0.125)`, metallic `0`, and perceptual roughness `0.5`. It therefore
reproduces the existing HDR reference. `goldMetal` uses scene-linear base color
`(1, 0.766, 0.336)`, metallic `1`, and perceptual roughness `0.35`, providing a
second independently bound response without prematurely defining the complete
Milestone 5 sphere scene.

## Milestone 5: Validate the Material Sphere Scene

### Outcome

The complete application render pathway displays a controlled set of material
responses without adding gameplay-light architecture to the PBR bootstrap.

### Change

- Build a deterministic validation scene containing several instances of the
  same sphere mesh.
- Assign authored materials that cover colored dielectrics, representative
  metals, and a deliberate roughness range.
- Keep one fixed Render-owned directional light with documented world-space
  direction, linear color, and intensity. Transform its direction into the
  BRDF's working space once per frame.
- Draw every sphere through the ordinary Game Content to Simulation snapshot to
  `RenderFrame` to material-resolution path.
- Use the normal, material-factor, diffuse, specular, HDR, and final-presented
  diagnostic views to isolate failures without changing render paths.
- Keep the scene and light values stable so later shader or resource-binding
  changes can be compared against the same reference.

### Checks

- Every sphere resolves the intended `MaterialID` while sharing one decoded
  mesh.
- Dielectrics retain diffuse response, while metals suppress it.
- Increasing roughness broadens and dims the specular highlight predictably.
- Camera movement preserves the world-space light direction and normal
  transforms.
- Bright values survive the HDR target and roll off only during presentation.
- Snapshot values remain detached from later ECS mutation.

### Implemented Conventions

The validation scene is a controlled `2 x 3` grid. All six ordinary ``Ball``
entities use `MeshID.ball`, remain at world-space `z = 0`, and differ only by
their position and `MaterialID`:

| Row | x = -1.75 | x = 0 | x = 1.75 | y |
| --- | --- | --- | --- | --- |
| Warm dielectric | `warmDielectricSmooth` | `warmDielectric` | `warmDielectricRough` | `1.10` |
| Gold metal | `goldMetalSmooth` | `goldMetal` | `goldMetalRough` | `-1.10` |

Within each row, base color and metallic remain constant while perceptual
roughness changes from left to right:

| Material family | Linear base color | Metallic | Roughness values |
| --- | --- | --- | --- |
| Warm dielectric | `(0.5, 0.25, 0.125)` | `0` | `0.2`, `0.5`, `0.8` |
| Gold metal | `(1, 0.766, 0.336)` | `1` | `0.2`, `0.35`, `0.8` |

The two established Milestone 4 baselines remain unchanged. Roughness `0.2`
avoids the evaluator's endpoint floor and an unnecessarily alias-sensitive
peak, while `0.8` gives each family a clearly broader comparison.

The entities retain their normal movement and rotation capabilities. Their
velocity, acceleration intent, impulse, angular velocity, and angular
accumulators all use zero/idle defaults, so the invariant Simulation schedule
leaves the scene quiescent. They do not advertise scale; ``RenderFrame`` applies
its existing `0.5` default. The default perspective camera remains at
`(0, 0, 8)`, and the fixed Render-owned world-space `+Z` directional light is
unchanged.

Validation deliberately adds no app-facing render path. Surface and view-space
normal modes remain the only `RenderOutputMode` cases. Test-addressable model
fragment entry points expose base color, metallic, effective roughness, diffuse,
and specular results while consuming the same `GPUInstance`, light record,
production model evaluator, argument-table binding helper, and shared BRDF as
the visible surface. Those functions are present in the bundled Metal library,
but only the test harness creates pipeline states for them; production code adds
no corresponding pipeline identity. The analytic proof measures roughness-lobe
shape using values resolved from the authored catalog. The production HDR
harness inspects both stored half-float radiance and final tone-mapped sRGB
presentation.

Builder tests freeze the six entities through the ordinary world, completed
snapshot, and Render-owned projection, prove quiescence across fixed steps, and
verify detachment from later ECS mutation. Catalog/model tests establish one
packaged and decoded sphere mesh. A shared production iteration seam proves that
the visible model loop visits all six projected instances in order, while the
GPU harness exercises that loop's exact per-draw instance-binding operation and
preserves six independent material identities.

At this point, stop. Textures, Forward+, shadows, atmosphere, and large-world
coordinates are separate changes with separate evidence and review.

## Forward+ Scaling Project

Forward+ remains Engine2's chosen production scaling direction. The single
directional-light baseline does not exercise its tiled or clustered assignment
stage because that global light affects every screen region. Forward+ work
begins with semantic local-light support, when representative content can
justify and measure the assignment design. That delay does not introduce a
competing renderer; it avoids fixing an unmeasured light-grid implementation.

The stable architectural flow is:

1. Render applies global directional lights independently of screen-region
   assignment.
2. Render projects semantic local lights into private GPU light records.
3. A Render-owned assignment stage produces a local-light list for each screen
   region.
4. The existing opaque shader evaluates its assigned local-light list using the
   same BRDF.

The focused Forward+ plan must then choose and justify exactly one assignment
implementation—tiles or clusters, compute or tile shader, bounds, capacities,
overflow behavior, and synchronization—using the supported devices,
resolutions, and representative local-light scenes. CPU reference assignment
may validate the chosen list contract before its GPU producer exists. It is a
test oracle and implementation step, not another production render path.

## Decisions Intentionally Deferred

These decisions are real, but they are not prerequisites for the material
sphere baseline:

- texture IDs, UVs, mipmaps, normal maps, tangent generation, and texture-table
  layout
- image-based lighting and environment ownership
- emissive materials, shadowing, and finite stellar emitters
- semantic light components, snapshot publication, and local-light types
- physically calibrated radiometric or photometric lights and camera exposure
- pre-exposure, automatic exposure, and a final tone-mapping look
- reversed-Z, `Double` or sector-local world positions, and render-origin policy
- atmosphere, clouds, rings, and transparency

The local proof scene does not establish large-world precision. That coordinate
work deserves its own architecture decision before Game Content uses distances
that exceed the current `Float` model.

## References

- [Filament: Roughness remapping and clamping](https://google.github.io/filament/main/filament.html#materialsystem/parameterization/roughnessremappingandclamping)
- [Understanding the Metal 4 core API](https://developer.apple.com/documentation/metal/understanding-the-metal-4-core-api)
- [Calculating primitive visibility using depth testing](https://developer.apple.com/documentation/metal/calculating-primitive-visibility-using-depth-testing)
- [Processing HDR images with Metal](https://developer.apple.com/documentation/metal/processing-hdr-images-with-metal)
- [Rendering a scene with Forward+ lighting using tile shaders](https://developer.apple.com/documentation/metal/rendering-a-scene-with-forward-plus-lighting-using-tile-shaders)
