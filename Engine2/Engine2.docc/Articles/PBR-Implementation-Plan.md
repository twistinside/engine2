# PBR Implementation Plan

This article defines the smallest explainable path from Engine2's current
vertex-color renderer to a direct-light physically based material renderer. It
also identifies where the already-chosen Forward+ light-selection work begins.

## Status

Proposed and not yet implemented.

The current renderer provides positions, display colors, and one
model-view-projection matrix. It has no normals, depth attachment, material
description, semantic light state, linear HDR target, or tone-mapping pass.

The plan deliberately stops short of specifying the eventual renderer in full.
Each milestone introduces one observable capability and must leave the engine
working without code from the next milestone.

## First Baseline

The first PBR baseline is intentionally narrow:

- opaque geometry
- base color, metallic, and perceptual roughness factors
- Lambert diffuse
- GGX distribution, Smith visibility, and Schlick Fresnel
- one or more point lights
- linear RGB lighting
- depth-correct drawing
- HDR scene color followed by explicit exposure and tone mapping

Emission is added with the first visible star material. Textures, image-based
lighting, shadows, atmospheres, and astronomical coordinate precision are not
required to prove this baseline.

PBR and Forward+ solve different problems. The baseline first proves the
material and light math with a complete light loop. Forward+ later changes how
Render selects the lights for each fragment; it does not introduce a second
BRDF or another selectable render path.

## Conventions Required Up Front

Only conventions consumed by the first milestones are fixed now:

- CPU and Metal matrix order and handedness must agree.
- Lighting vectors and surface positions are evaluated in one documented
  coordinate space; view space is the initial choice.
- Normals use the inverse transpose of the model-view transform and are
  normalized after interpolation.
- Material and light calculations use finite linear RGB values.
- Base color, metallic, and roughness have documented legal ranges.
- Point-light attenuation uses one documented inverse-square equation and one
  Render-owned minimum-distance safeguard.
- The BRDF equations are written once and shared by proof and production
  shading.

The first light intensity and exposure values are scene-linear controls, not a
claim of calibrated stellar photometry. Physical units, a physical camera, and
consistent derivation of a star's visible emission and emitted power require a
separate decision when real astronomical content is ready.

## Ownership

### Game Content

Game Content owns the identities, authored description values, and packaged
assets that make the game distinct. It populates Render-owned backend-neutral
catalog contracts but never owns decoded Metal resources.

The bootstrap star and planet share sphere geometry but require different
appearances. Game Content therefore owns a strongly typed `MaterialID` as well
as `MeshID`; the engine must not invent duplicate mesh identities or decode the
same geometry twice to distinguish materials.

### Simulation Runtime

Simulation remains authoritative for semantic world state:

- `CRenderable` currently stores `MeshID`; the authored-material milestone adds
  `MaterialID`. Snapshot capture iterates that store and joins position,
  rotation, and scale from their separate components.
- A point-light component stores only semantic color and intensity.
- The light's position comes from the same authoritative `CPosition` used by a
  visible star entity; it is not duplicated in the light component.
- A completed presentation snapshot publishes a detached flat light array.

One entity may therefore be both renderable and a point light. Its material
makes the star visible; its light component illuminates other entities. Neither
capability implies the other.

### Render Runtime

Render owns:

- decoded vertex and index buffers
- material and light GPU representations
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

- Extend the decoded vertex input from position and display color to position
  and normal.
- Preserve authored normals. If the example sphere lacks them, add the smallest
  explicit asset-loading rule needed for that asset rather than designing a
  general normal-generation policy.
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
- Supply one renderer-owned constant material and point light.
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
- Grazing and coincident inputs remain finite.
- The offscreen target contains linear values rather than gamma-encoded color.

## Milestone 3: Visible HDR PBR

### Outcome

The application visibly renders the proof material through a correct linear HDR
presentation chain.

### Change

- Add a renderer-owned `rgba16Float` scene target.
- Draw the same proven BRDF into that target with the renderer-owned proof
  material and light.
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

## Milestone 4: Authored Material Boundary

### Outcome

A renderer-owned proof material is replaced by an authored Game Content
material without exposing Metal resources or unnecessary presentation state.

### Change

- Define the minimal Render-owned `PBRMaterialDescription` contract with base
  color, metallic, roughness, and emission factors.
- Let Game Content define `MaterialID` and supply the example material
  descriptions through `RenderAssetCatalog`.
- Add `MaterialID` to `CRenderable`, renderable spawn seeding, snapshot capture,
  and `RenderInstance` so the shared sphere mesh can represent both star and
  planet appearances.
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
- Two entities share one decoded mesh when their appearance differs.
- Material factors and Metal resources never enter ECS or a Simulation
  snapshot. Only `MaterialID` crosses that boundary.

## Milestone 5: Semantic Point-Light Boundary

### Outcome

A point light becomes authoritative Simulation state and replaces the
renderer-owned proof light through the existing snapshot boundary.

### Change

- Add the smallest typed point-light capability and component: color and a
  nonnegative finite scene-linear intensity.
- Make `PPointLight` require `PPositionable` so a light entity has authoritative
  position state while keeping position only in `CPosition`.
- Add `World.pointLightComponents`, and extend `World.add(_:from:)` to seed its
  row from point-light capability values.
- Carry focused light seed values through the concrete star initializer and
  capability properties; do not enlarge `Entity.InitialState` with light data.
- Publish point-light presentation values in a flat array keyed by `EntityID`.
  Array order is not identity.
- Join the required position from `CPosition` during snapshot capture. A missing
  position row is an invariant violation, not an optional invisible light.
- Project the array into Render-owned view-space light records.
- Evaluate the complete projected light array in the opaque shader.
- Remove only the renderer-owned proof light after semantic content reproduces
  the reference result.

### Checks

- A light can exist without a mesh, and an emissive mesh can exist without a
  light.
- A star with both capabilities uses one authoritative position.
- Snapshot values remain detached from later ECS mutation.
- Zero, one, and several lights render without hidden truncation.
- The Simulation Runtime remains correct when no Render Runtime consumes the
  snapshot.

## Milestone 6: Validate the Actual Space Scene

### Outcome

The engine has an explainable direct-light PBR renderer, and its next work is
chosen from observed shortcomings rather than from a speculative final design.

Use a representative scene containing a visible star, at least one planet, and
the camera distances expected during early gameplay. Validate:

- planet normals, metallic, and roughness response
- the illuminated and unilluminated sides of the planet
- star emission under the HDR presentation path
- actual light counts and fragment light-loop cost
- the coordinate precision available from the current `Float` world

At this point, stop. Textures, Forward+, shadows, atmosphere, and large-world
coordinates are separate changes with separate evidence and review.

## Forward+ Scaling Project

Forward+ remains Engine2's chosen production scaling direction. It begins when
representative content shows that evaluating the complete light array is a
material cost or when planned local-light content makes that cost predictable.
That delay does not introduce a competing renderer; it avoids fixing an
unmeasured light-grid implementation.

The stable architectural flow is:

1. Render projects semantic lights into private GPU light records.
2. A Render-owned assignment stage produces a light list for each screen
   region.
3. The existing opaque shader evaluates only its assigned list using the same
   BRDF.

The focused Forward+ plan must then choose and justify exactly one assignment
implementation—tiles or clusters, compute or tile shader, bounds, capacities,
overflow behavior, and synchronization—using the supported devices,
resolutions, and representative local-light scenes. CPU reference assignment
may validate the chosen list contract before its GPU producer exists. It is a
test oracle and implementation step, not another production render path.

## Decisions Intentionally Deferred

These decisions are real, but they are not prerequisites for the first lit
planet:

- texture IDs, UVs, mipmaps, normal maps, tangent generation, and texture-table
  layout
- image-based lighting and environment ownership
- shadowing and finite stellar emitters
- physically calibrated radiometric or photometric lights and camera exposure
- pre-exposure, automatic exposure, and a final tone-mapping look
- reversed-Z, `Double` or sector-local world positions, and render-origin policy
- atmosphere, clouds, rings, and transparency

The local proof scene does not establish astronomical-scale precision. That
coordinate work deserves its own architecture decision before Game Content uses
real solar-system distances.

## References

- [Understanding the Metal 4 core API](https://developer.apple.com/documentation/metal/understanding-the-metal-4-core-api)
- [Calculating primitive visibility using depth testing](https://developer.apple.com/documentation/metal/calculating-primitive-visibility-using-depth-testing)
- [Processing HDR images with Metal](https://developer.apple.com/documentation/metal/processing-hdr-images-with-metal)
- [Rendering a scene with Forward+ lighting using tile shaders](https://developer.apple.com/documentation/metal/rendering-a-scene-with-forward-plus-lighting-using-tile-shaders)
