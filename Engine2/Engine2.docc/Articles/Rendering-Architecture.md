# Rendering Architecture
This article captures the intended rendering direction for Engine2.
## Status
Partially implemented.
The current codebase already has:
- ``SimulationPresentationSnapshot`` as the Simulation Runtime-owned completed presentation value
- ``RenderViewpoint`` plus `PRenderViewpointSource` as the immutable output-specific camera boundary
- ``RenderFrame.project(from:viewpoint:)`` as the Render Runtime-owned private projection, preserving source-cursor and optional viewpoint attribution
- ``MetalSceneView`` as the SwiftUI/MetalKit bridge
- ``MetalFrameEncoder`` as the view-independent owner of reusable Metal frame preparation and encoding
- ``MetalRenderer`` as the thin MetalKit adapter that samples presentation and viewpoint sources, owns screen submission/presentation policy, and delegates encoding
- ``ScreenViewpointController`` as the App-owned free-orbit controller for the current screen output
- `MetalResourceStore` as the device-scoped owner of the Metal 4 compiler,
  command queue, typed state caches, decoded models, and frame-resource ring
- `MetalResidencyManager` as the owner of committed static-asset and
  frame-allocation residency sets
- typed `MeshID` and `MaterialID` values plus a `RenderAssetCatalog` boundary
  between Game Content descriptions and renderer-owned resources
The production frame encoder is also exercised by a real render integration test using caller-owned offscreen textures, explicit residency and queue feedback, and texture readback without an `MTKView` or `CAMetalDrawable`. This proves the encoding boundary; it does not yet provide a production `RenderRuntime`, offscreen request/result API, artifact/JPEG contract, or asynchronous render worker. The broader ideas below describe where that path is expected to grow.
See <doc:Runtime-Architecture> for the canonical Runtime, Snapshot, Event, and runtime-boundary vocabulary.
See <doc:Runtime-Communication> for the proposed publisher-owned snapshot and consumer-owned projection model.
See <doc:PBR-Implementation-Plan> for the staged path from the current visible
renderer through a directional-light PBR baseline and into the later Forward+
local-light scaling work. Its normals/depth foundation, shared direct-light
BRDF, visible HDR presentation chain, and authored material boundary are
implemented, and a controlled six-sphere material scene now validates the
complete bootstrap pathway.
## Chosen Rendering Path
Engine2's planned production renderer uses one **Forward+** path with
**physically based rendering (PBR)**. Render owns one shared direct-light BRDF
implementation used by both its isolated proof and its visible path. The
visible renderer resolves authored material identities into per-draw factors,
shades into linear `rgba16Float`, then applies explicit manual exposure and
Reinhard tone mapping before writing display-linear values to an sRGB drawable.
Forward+ light assignment remains future work.

Forward+ separates light assignment from surface shading:

1. The Render Runtime determines which lights can affect each screen tile or
   view-space cluster.
2. A material shader evaluates only the relevant light list while drawing its
   surface.
3. The shader writes the final lit surface color directly to the HDR color
   target.

This remains forward rendering because material evaluation and lighting occur
while the surface is drawn. The `+` refers to tiled or clustered light
selection, not to a deferred lighting pass. Engine2 does not plan to maintain
runtime-selectable forward and deferred paths, and its core path does not use a
general-purpose G-buffer followed by a separate opaque-lighting pass.

Apple GPU **tile-based deferred rendering** describes how the hardware
schedules rasterization and retains tile data. It is distinct from the deferred
shading technique and remains useful to Engine2's Forward+ renderer.

PBR defines how materials and lights produce a surface response; Forward+
defines how the renderer finds relevant lights and when it evaluates that
response. The intended PBR model uses linear HDR lighting, physically meaningful
light inputs, and energy-conserving material response. Game Content supplies
backend-neutral material identities and assets, Simulation publishes only the
semantic presentation facts that can change, and the Render Runtime privately
resolves those values into Metal resources and shader inputs.

Planet surfaces and other opaque geometry use the Forward+ PBR path directly.
Clouds, atmospheres, rings, and other transparent or volumetric layers remain
ordered forward phases that may reuse the same lighting descriptions and light
lists. A feature may introduce a focused auxiliary target such as depth or
normals, but that does not turn the core renderer into a deferred path.
## Rendering Belongs to the Render Runtime
Rendering is owned by the proposed Render Runtime, not by an ECS gameplay system that mutates authoritative state.
Simulation systems update `World`, the Simulation Runtime publishes an immutable `SimulationPresentationSnapshot`, and the Render Runtime projects the latest completed value into private render-oriented state according to its own cadence. The Simulation Runtime remains valid when no Render Runtime is present; its presentation snapshot simply has no consumer.
## Simulation Truth Stays in ECS
Rendering should not become a second gameplay state model.
The authoritative simulation state should remain in ECS component stores. Render code should consume a completed `SimulationPresentationSnapshot`, not read or mutate gameplay state directly through entity objects during drawing.
`World` may still contain abstract presentation state such as mesh handles, material handles, visibility, Simulation-authoritative camera settings, and render style. Its published camera is the current default when an output supplies no override. Output-specific free orbit and zoom belong to presentation ownership, and `World` should not contain backend-specific Metal objects.

The current `CRenderable` component demonstrates that distinction. It stores a
`MeshID` and `MaterialID`, while `BasicGameContent` maps `MeshID.ball` to the
packaged `Ball.usdz` asset and maps its closed material identities to
`PBRMaterialDescription` values. The Render Runtime's `MetalResourceStore`
receives that catalog and privately owns the validated descriptions, decoded
meshes, buffers, compiled state, and residency organization consumed by
``MetalFrameEncoder`` and its callers.
## Rendering Projects Published Simulation State
The implemented runtime boundary separates publication and projection:

- `World` remains private authoritative simulation state
- the Simulation Runtime publishes a completed, backend-neutral `SimulationPresentationSnapshot`
- the App may supply a separately owned output-specific `RenderViewpoint`
- the Render Runtime selects and projects the scene and resolved viewpoint it needs
- the renderer consumes its private render snapshot and backend resources

This accepts that any explicitly connected presentation consumer can observe fields in `SimulationPresentationSnapshot` that it does not currently use. It still cannot mutate simulation state, inspect ECS storage machinery, or access `World` directly.
## Render Projection
The renderer consumes a flat ``RenderFrame`` of `RenderInstance` values projected from one exact ``SimulationPresentationSnapshot`` and an optional explicit ``RenderViewpoint``. ``RenderFrame.project(from:viewpoint:)`` is render-owned because only Render knows which destination fields and derived values it needs. The presentation snapshot already contains only entities with explicit abstract presentation state; Render filters that set for the position it needs and applies render defaults.

When a viewpoint is supplied, its camera overrides the snapshot's default and the frame preserves its ``RenderViewpointID`` and ``RenderViewpointRevision`` beside the source ``SimulationCursor``. Without one, the frame uses the snapshot camera exactly and leaves viewpoint attribution absent. Distinct explicit viewpoints can therefore project the same immutable Simulation cursor without fabricating extra ticks.

The render-oriented structs may grow to represent only the data needed to issue draw calls, such as:
- transform data
- mesh handle
- material handle
- render pipeline key
- sort or batch key
- any other renderer-facing flags needed for visibility, instancing, or ordering
These projected values should be small, stable, and detached from gameplay-facing entity objects.
The important boundary is that Simulation publishes completed observable facts while Render defines its private frame format.

## Viewpoint Resolution Is Output-Specific

The current interactive screen owns a ``ScreenViewpointController`` in ``RealtimeAssembly``. Before its first meaningful drag or scroll, and after reset, it passes through the latest Simulation-published camera exactly. A meaningful gesture seeds its orbit state from that default and advances a monotonic viewpoint revision without mutating Simulation.

At draw cadence, `MetalRenderer` samples one ``SimulationPresentationSnapshot``, then asks its optional `PRenderViewpointSource` to resolve against that same snapshot's camera. This ordering makes the camera fallback explicit and keeps the scene cursor stable when only presentation changes. The current ``RealtimeAssembly`` hard-codes screen-event delivery to the controller; typed input routes, route epochs, per-window controllers and bindings, Simulation observer anchors, and a production offscreen viewpoint source remain proposed.
## Snapshot Publication and Storage
``SimulationRuntime.latestPresentationSnapshot`` is the first explicit latest-value publication slot. Every successful exact advance replaces it after the entire requested batch completes; in the current real-time configuration, ``RealtimeAdvanceDriver`` requests those batches from elapsed wall time. Slow consumers may therefore skip superseded cursors by design. The clock-free manual assembly uses the same Runtime boundary, and future supported advancement paths must update required publications there according to each lane's declared semantics.

The current model is:
1. Simulation publishes a completed `SimulationPresentationSnapshot` through a latest-value boundary
2. Render selects the latest available presentation snapshot when it is ready
3. Render independently resolves the configured output viewpoint against that snapshot's default camera
4. Render projects both values into its private render snapshot or back buffer
5. Render presents from the latest completed private value

This keeps rendering from reading partially updated simulation data and allows it to skip superseded presentation snapshots. Retained history, replay journals, subscription APIs, and private Render front/back buffering remain future work rather than responsibilities of the ordinary latest-value slot.
## Draws Follow Presentation Cadence
Drawing should be allowed to happen on a different cadence from simulation ticking.
In practice, a Metal view or display callback will dictate when a draw can occur because it provides the current drawable. That should drive presentation timing, not gameplay authority.
The intended model is:
- fixed-step simulation updates `World`
- Simulation publishes a completed simulation presentation snapshot
- Render projects the latest available value into render data
- rendering consumes the latest completed front buffer when a draw is requested
This allows zero, one, or many simulation ticks between draws without making draw cadence the owner of simulation state.

It also allows the current screen controller to change a viewpoint while ``RealtimeAdvanceDriver`` is paused. A later draw can then use a higher viewpoint revision with the same source Simulation cursor and entity presentation. The renderer neither requests a tick nor reads raw input to make that happen.

The MetalKit screen adapter is only one caller of the reusable encoding boundary. A render integration test constructs the production ``MetalFrameEncoder``, supplies its own offscreen color, depth, and destination textures and `FrameResources`, begins a Metal 4 command buffer, manages residency and feedback, and reads back the rendered destination without a view or drawable. A future production offscreen caller still needs request validation, target-allocation policy, submission lifetime, asynchronous completion, readback and encoding, artifact metadata, and failure semantics.

That latest-value model is appropriate for a screen surface. An offline render workflow instead needs an exact immutable snapshot correlated with its advance request and may render it for minutes, many samples, or several cameras before an App-owned coordinator requests the next Simulation tick. Render completion may therefore gate further advancement without giving the Render Runtime ownership of Simulation. See <doc:Runtime-Configurations-and-Advancement>.

Rendering is snapshot-only. It does not rely on receiving simulation events. A transient visual occurrence must therefore remain represented in snapshot-visible presentation state long enough for a renderer that skips intermediate snapshots to observe or converge past it correctly.
## Batching
Once render items are extracted, the renderer should be able to batch or sort them by renderer-relevant state.
The first useful batching keys are likely:
- render pipeline state
- material
- mesh
That keeps draw ordering decisions in the render pipeline instead of scattering them across gameplay objects.
Gameplay state can still influence the eventual pipeline choice through abstract render style or material data. The Render Runtime's projection and resource layers are responsible for resolving that abstract intent into concrete pipeline keys and backend objects.
## Resource Handles
ECS components should prefer stable renderer-facing handles or keys over raw Metal objects where practical.
For example, gameplay code can refer to a mesh ID, material ID, visibility flag, or render style, and the Render Runtime can project and resolve those values to actual pipeline keys and Metal resources.
This keeps Metal-specific ownership and lifetime concerns inside the render layer.
The identities, presentation descriptions, and source assets that differentiate a particular game belong to Game Content. The Render Runtime receives the relevant catalogs during App construction and privately resolves them into backend resources. See <doc:Game-Content-Architecture>.

## Device-Scoped Metal Resources

`MetalResourceStore` is the current device-scoped root for backend resources.
One store owns exactly one `MTLDevice`; selecting a different device requires a
different store and a different set of compiled and allocated objects.

The store eagerly creates the resources required by the current renderer:

- an `MTL4Compiler` and `MTL4CommandQueue`
- loaded shader libraries keyed by `MetalShaderLibraryID`
- Metal 4 render pipelines keyed by `MetalRenderPipelineID`
- depth-stencil states keyed by `MetalDepthStencilStateID`
- argument tables keyed by `MetalArgumentTableID`
- decoded models resolved from backend-neutral `MeshID` values
- validated authored descriptions resolved from backend-neutral `MaterialID`
  values
- the fixed frame-resource ring and its PBR/presentation parameter buffers
- the PBR scene, normal diagnostic, tone-mapped presentation, and linear
  diagnostic pipelines

Each backend identity is a closed Render Runtime enum whose case determines the
complete resource definition. The store builds each case once and retains the
result for lookup. Required resources are compiled before drawing begins, so
``MetalFrameEncoder`` performs deterministic lookup rather than shader or pipeline compilation while preparing or encoding a frame.
Catalog or renderer construction failures remain observable through the
`MetalSceneView` coordinator's latest render error rather than being discarded
when the bridge cannot create a renderer.

Future vertex layouts, function constants, blend state, and attachment
variants should become explicit enum cases or deliberately modeled variant
keys instead of silently sharing a pipeline identity.

## View-Independent Metal Frame Encoding

``MetalFrameEncoder`` owns the backend work shared by screen and future offscreen callers:

- authored-material preflight for the bounded submitted instance prefix
- the fixed `rgba16Float` scene, `depth32Float` depth, and `bgra8Unorm_srgb` destination format contract
- `FrameResources` buffer packing
- model, diagnostic, depth, and presentation pipeline and argument-table selection
- the ordered HDR scene and presentation pass
- model draw iteration and binding

The caller supplies one prepared ``RenderFrame``, caller-owned scene-color, depth, and destination textures with matching positive dimensions and formats, an available `FrameResources` slot, and an already-begun `MTL4CommandBuffer`. The encoder records work but does not sample Simulation or viewpoint sources, choose or wait for a frame-ring slot, acquire an `MTKView` or `CAMetalDrawable`, begin, end, or submit a command buffer, manage target residency or completion feedback, present an image, or decide whether an error is terminal.

``MetalRenderer`` now owns exactly those screen-specific policies: latest-source and viewpoint sampling, ring-slot arbitration, drawable and depth acquisition, target and residency hookup, queue submission and feedback lifetime, drawable presentation, and terminal screen error state. `MetalResourceStore.defaultFrameCount` and compiled target formats no longer depend on the adapter; the store owns its default ring cardinality and compiles against ``MetalFrameEncoder``'s format contract.

## Metal 4 Residency Sets

Residency and Swift object ownership are separate responsibilities. The resource
store strongly retains models, buffers, pipeline states, and other backend
objects. `MetalResidencyManager` groups only objects conforming to
`MTLAllocation` so the Metal 4 command queue can ensure those allocations are
resident when submitted work uses them.

The current implementation uses two queue-wide Render Runtime-owned sets:

- **Static Render Assets** contains immutable model vertex and index buffers.
- **Render Frame Buffers** contains the CPU-written transform/material instance,
  light-only PBR-scene, and presentation-parameter buffers in the frame ring.

In addition, each reusable frame slot lazily owns one drawable-sized HDR scene
target and one committed residency set containing that target. The set is
attached to the exact command buffer that uses it, and the in-flight submission
token retains the target and set until queue feedback completes. Resize replaces
a slot's target only after that slot is no longer in flight.

Those are current screen-caller lifetime choices, not responsibilities hidden inside ``MetalFrameEncoder``. The offscreen integration test supplies and retains its own destination and depth targets and committed residency set, attaches both caller- and frame-owned sets, releases the frame slot from explicit queue feedback, and performs readback only after completion.

MetalKit and Core Animation continue to own their drawable-related allocations.
Their view and layer residency sets are registered with the command queue when
the `MTKView` is configured rather than copied into an engine-owned set.

Pipeline states, shader libraries, depth-stencil states, compilers, and argument
tables are retained in typed caches but are not `MTLAllocation` values and do
not belong in these residency sets.
## Intended Frame Shape
A likely long-term frame flow is:
1. simulation systems update ECS state
2. the Simulation Runtime publishes a completed `SimulationPresentationSnapshot`
3. the output resolves an explicit viewpoint or uses the snapshot's default camera
4. the Render Runtime projects the scene and viewpoint into render items
5. render items are sorted or batched
6. private front and back render buffers swap
7. Render constructs tiled or clustered light lists for the frozen frame
8. a caller selects targets, frame resources, submission lifetime, and output policy
9. ``MetalFrameEncoder`` prepares and records the reusable GPU work
10. opaque surfaces are shaded through the Forward+ PBR path
11. ordered forward layers such as clouds, atmospheres, rings, and transparency are composed
12. shared post-processing produces the caller-owned destination image
This is the intended path toward deterministic simulation, cleaner render isolation, and later optimizations such as culling and instancing.
## Related Direction
This rendering approach fits the broader engine direction:
- ``World`` remains the authoritative simulation container
- ``PSystem`` implementations continue to operate on ECS data
- the Simulation Runtime publishes its own presentation snapshot without requiring a Render Runtime
- output-specific viewpoints can change without mutating or advancing Simulation
- the Render Runtime projects published state plus an explicit viewpoint instead of reading live simulation objects
## Topics
### Architecture
- <doc:Runtime-Architecture>
- <doc:Runtime-Configurations-and-Advancement>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
- <doc:PBR-Implementation-Plan>
### Related Symbols
- ``Engine``
- ``PResource``
- ``World``
- ``ComponentStore``
