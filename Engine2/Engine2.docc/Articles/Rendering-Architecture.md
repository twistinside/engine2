# Rendering Architecture

This article captures the intended rendering direction for Engine2.

## Status

Partially implemented.

The current codebase already has:
- ``SimulationPresentationSnapshot`` as the Simulation Runtime-owned completed presentation value
- `RenderFrame(projecting:)` as the snapshot-camera-locked screen projection
- ``MetalSceneView`` as the SwiftUI/MetalKit bridge
- `MetalScenePlatformView` as the single onscreen `MTKView`, drawable surface, and thin AppKit input-ingress adapter
- ``MetalFrameEncoder`` as the view-independent owner of reusable Metal frame preparation and encoding
- ``MetalRenderer`` as the `MTKView` delegate that samples one presentation source, uses that snapshot's camera exactly, owns screen submission/presentation policy, and delegates encoding
- a real-time screen path whose camera is locked to the latest completed Simulation presentation
- `MetalResourceStore` as the device-scoped owner of the Metal 4 compiler,
  command queue, nonoptional built-in required-resource set, decoded models,
  and frame-resource ring
- `MetalResidencyManager` as the owner of committed static-asset and
  frame-allocation residency sets
- typed `MeshID` and `MaterialID` values plus a `RenderAssetCatalog` boundary
  between Game Content descriptions and renderer-owned resources

The current screen implementation does not define a long-lived `RenderRuntime`
type. ``RealtimeAssembly`` passes Game Content's catalog and a read-only
Simulation presentation source into ``MetalSceneView``. The view's coordinator
constructs and retains ``MetalRenderer`` for that view's lifetime, and the
renderer retains its ``MetalResourceStore``. An in-flight submission may retain
the required resource graph beyond view teardown until queue feedback arrives.
References to the Render Runtime below describe the intended top-level owner
unless a paragraph names one of these implemented types.

The production frame encoder is exercised by the screen adapter and direct
Render integration tests. A production offscreen output, snapshot export,
replay, and agent control are outside the current release.

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
response. The current baseline uses finite scene-linear validation inputs and
an energy-conserving material response; physically calibrated light units and
camera exposure remain future work. Game Content supplies
backend-neutral material identities and assets, Simulation publishes only the
semantic presentation facts that can change, and the Render Runtime privately
resolves those values into Metal resources and shader inputs.

The planned renderer places planet surfaces and other opaque geometry on the
Forward+ PBR path. Clouds, atmospheres, rings, and other transparent or
volumetric layers would remain ordered forward phases that may reuse the same
lighting descriptions and light lists. A feature may introduce a focused
auxiliary target such as depth or normals without turning the core renderer
into a deferred path.

## Rendering Belongs to the Render Runtime

Rendering is owned by the proposed Render Runtime, not by an ECS gameplay system that mutates authoritative state.
Simulation systems update `World`, the Simulation Runtime publishes an immutable `SimulationPresentationSnapshot`, and the Render Runtime projects the latest completed value into private render-oriented state according to its own cadence. The Simulation Runtime remains valid when no Render Runtime is present; its presentation snapshot simply has no consumer.

## One Platform View Serves Rendering and Input Ingress

``MetalSceneView`` creates one `MetalScenePlatformView`. That `MTKView` provides the drawable surface, and ``MetalRenderer`` remains its delegate for draw cadence, drawable acquisition, encoding, submission, and presentation. There is no separate input view or transparent overlay.

The same platform view receives AppKit focus, keyboard, pointer, drag, and scroll callbacks because it already defines the interactive scene's coordinate space. It converts those callbacks into physical `InputEvent` values and submits them through `InputEventSink`. ``InputRuntime`` owns semantic mapping. `MetalScenePlatformView` neither encodes render work nor decides what a key, button, or pointer gesture means to gameplay.

## Simulation Owns Gameplay State

Components own authoritative gameplay values and lifecycle state, and Entity owns identity.
Render code consumes a completed `SimulationPresentationSnapshot`; it does not read or mutate live gameplay values or entity lifecycle during drawing.
`World` currently owns abstract mesh and material identities plus the
Simulation-authoritative camera. Future presentation state may add visibility
or render-style values while remaining backend-neutral. The published camera
is the exact camera used by the current real-time screen. ``InputRuntime``
publishes cumulative semantic orbit and zoom totals, and
``CameraInputSystem`` applies their interval deltas only during a complete
Simulation tick. Future photo, editor, replay, spectator, or multi-window
assemblies may deliberately own interactive output viewpoints, but those are
separate modes rather than a pause-time bypass. `World` should not contain
backend-specific Metal objects.

The current `RenderableComponent` component demonstrates that distinction. It stores a
`MeshID` and `MaterialID`, while `BasicGameContent` maps `MeshID.ball` to the
packaged `Ball.usdz` asset and maps its closed material identities to
`PBRMaterialDescription` values. The current screen's `MetalResourceStore`
receives that catalog and privately owns the validated descriptions, decoded
meshes, buffers, compiled state, and residency organization consumed by
``MetalFrameEncoder`` and its callers.
## Rendering Projects Published Simulation State

The implemented runtime boundary separates publication and projection:

- `World` remains private authoritative simulation state
- the Simulation Runtime publishes a completed, backend-neutral `SimulationPresentationSnapshot`
- the current real-time screen uses the snapshot camera exactly
- the current render path projects the scene and camera from that completed value
- the renderer consumes its private ``RenderFrame`` and backend resources

This accepts that any explicitly connected presentation consumer can observe fields in `SimulationPresentationSnapshot` that it does not currently use. It still cannot mutate simulation state, inspect ECS storage machinery, or access `World` directly.
## Render Projection
The renderer consumes a flat ``RenderFrame`` of `RenderInstance` values. Its
`RenderFrame(projecting:)` initializer accepts one exact
``SimulationPresentationSnapshot``, uses that snapshot's camera, and preserves its
``SimulationCursor``. This API shape
prevents live screen code from selecting a camera that Simulation has not
published. The presentation snapshot already contains only entities with
explicit abstract presentation state; Render filters that set for the position
it needs and applies render defaults. `RenderInstance.init(projecting:viewMatrix:)`
owns the per-entity transform construction and normal-matrix validation, then
retains the validated model-view and inverse-transpose normal matrices for GPU
packing.

The render-oriented structs may grow to represent only the data needed to issue draw calls, such as:

- transform data
- mesh identity
- material identity
- render pipeline key
- sort or batch key
- any other renderer-facing flags needed for visibility, instancing, or ordering
These projected values should be small, stable, and detached from gameplay-facing entity objects.
The important boundary is that Simulation publishes completed observable facts while Render defines its private frame format.

## Selected-Entity Inspection Is Not Render Projection

The mining slice's SwiftUI inspector is App presentation, not a Render Runtime projection. It receives the selected live entity through a narrow, read-only Simulation-owned source and conditionally presents protocol-backed capabilities such as selection with its required hit bound, motion, orbit, mass, propulsion, fuel, cargo, shared interaction range, mining, depot service, and collision. Its orbit-assist button receives a separate focused callback that passes the displayed entity's full identity through the real-time assembly and its sole advance authority.

The inspector does not read `RenderFrame`, backend resources, or `World`, and the callback cannot mutate the facade. ``OrbitCircularizationCommand`` travels on a cursor-qualified Simulation request rather than through Render or ``InputRuntime``. ``SimulationPresentationSnapshot`` remains the scene-and-camera contract for rendering and does not acquire gameplay fields or commands merely because an in-process UI wants to inspect or act on one entity.

## The Real-Time Screen Uses the Simulation Camera

At draw cadence, `MetalRenderer` samples one ``SimulationPresentationSnapshot`` and calls `RenderFrame(projecting:)`. The frame therefore uses `snapshot.camera` exactly and preserves the source ``SimulationCursor``. Physical host input and semantic intent are not interpreted by Render and cannot revise the screen camera independently.
## Snapshot Publication and Storage

`SimulationRuntime.latestPresentationSnapshot` is the first explicit latest-value publication slot. Every successful exact advance replaces it after the entire requested batch completes; in the current real-time assembly, ``RealtimeAdvanceDriver`` requests those batches from elapsed wall time. Slow consumers may therefore skip superseded cursors by design. Future supported advancement paths must update required publications according to each lane's declared semantics.

The current model is:

1. Simulation publishes a completed `SimulationPresentationSnapshot` through a latest-value boundary
2. `MetalRenderer` samples the latest available presentation after acquiring a reusable frame slot
3. `RenderFrame(projecting:)` projects that snapshot with its published camera exactly
4. ``MetalFrameEncoder`` prepares and records work into caller-owned targets
5. `MetalRenderer` submits and presents that work

This keeps rendering from reading partially updated simulation data and allows it to skip superseded presentation snapshots. Retained history, replay journals, subscription APIs, and private Render front/back buffering remain future work rather than responsibilities of the ordinary latest-value slot.
## Draws Follow Presentation Cadence

Drawing should be allowed to happen on a different cadence from simulation ticking.
In practice, a Metal view or display callback will dictate when a draw can occur because it provides the current drawable. That should drive presentation timing, not gameplay authority.

The implemented screen model is:

- fixed-step simulation updates `World`
- Simulation publishes a completed simulation presentation snapshot
- `MetalRenderer` projects the latest available value when a draw is requested
- ``MetalFrameEncoder`` records the projected frame into the screen's current targets

This allows zero, one, or many simulation ticks between draws without making draw cadence the owner of simulation state.

While ``RealtimeAdvanceDriver`` is paused, the screen may redraw the last completed value, but both its scene and camera remain frozen at that snapshot. A screen-camera change requires a newly completed Simulation publication. A future photo-mode or editor assembly may introduce presentation-owned camera control without a Simulation tick, but that is not current real-time behavior.

Rendering is snapshot-only. It does not rely on receiving simulation events. A transient visual occurrence must therefore remain represented in snapshot-visible presentation state long enough for a renderer that skips intermediate snapshots to observe or converge past it correctly.
## Future Batching

Once render items are extracted, the renderer should be able to batch or sort them by renderer-relevant state.
The first useful batching keys are likely:

- render pipeline state
- material
- mesh
That keeps draw ordering decisions in the render pipeline instead of scattering them across gameplay objects.
Gameplay state can still influence the eventual pipeline choice through abstract render style or material data. The Render Runtime's projection and resource layers are responsible for resolving that abstract intent into concrete pipeline keys and backend objects.
## Backend-Neutral Resource Identities

ECS components should carry stable backend-neutral identities instead of raw
Metal objects. The current `RenderableComponent` uses `MeshID` and `MaterialID`;
future visibility or render-style values should preserve the same boundary. The
Render Runtime can project and resolve those identities into pipeline keys and
Metal resources.
This keeps Metal-specific ownership and lifetime concerns inside the render layer.
The identities, presentation descriptions, and source assets that differentiate a particular game belong to Game Content. The Render Runtime receives the relevant catalogs during App construction and privately resolves them into backend resources. See <doc:Game-Content-Architecture>.

## Shared CPU/GPU Layout Headers

Raw records that cross the Swift/Metal ABI use focused C-compatible headers as
their single field declaration. Swift imports these headers through
`Engine2-Bridging-Header.h`, while Metal Shading Language includes the same
record header directly. The umbrella bridging header is only an import manifest;
it does not contain layouts itself.

The current shared production records are:

- `ModelVertex`, the Model I/O-to-shader interleaved vertex record
- `GPUInstance`, the per-draw transform and authored-material transport record
- `PBRSceneParameters`, the frame's directional-light transport record
- `HDRPresentationParameters`, the presentation pass's exposure record

The isolated render proof similarly shares `PBRProofParameters` between its
shader and the Render integration-test target through a test-specific bridging
header. It remains a provisional test contract rather than production ABI.

Sharing a declaration prevents a Swift struct and an MSL struct from drifting,
but it does not turn the wire record into a semantic API. Swift types such as
`PBRMaterialDescription`, Game Content identities such as `MaterialID`, and
validation policy remain ordinary Swift values. ``RenderInstance`` owns
transform projection and validation, while focused Swift extensions pack its
retained values and other validated semantic inputs into imported transport
records such as `GPUInstance`.

Each shared header should declare one coherent raw record and use only
exact-width scalar integers, `float`, and the SIMD vocabulary accepted by both
compilers. Prefer explicit matrix and four-component vector lanes when the ABI
needs their alignment. Use explicit padding fields when needed, and initialize
that padding deterministically. In particular, `simd_float3` values and the
columns of `simd_float3x3` occupy 16-byte lanes; they are not packed 12-byte
values. Replacing one with `MTLPackedFloat3` or another packed representation is
an ABI change that requires coordinated descriptor and layout-test updates.
Avoid size-dependent or ownership-bearing fields such as:

- Swift `Bool` or `Int`, C `bool`, `int`, `long`, or `size_t`
- references, optionals, strings, and collections
- ECS entities, Game Content values, or renderer resource objects
- raw `MTLBuffer`, texture, sampler, or pipeline objects

Closed buffer, texture, sampler, and attribute index constants may also be
shared when both compilers consume them, but they should remain focused on one
binding contract rather than accumulating into a universal shader-types header.

Shader-only implementation stays in `.metalh` files. BRDF helpers, stage
outputs, and intermediate calculation records that Swift never reads gain
nothing from a C interoperability boundary. Conversely, a record written by
Swift and interpreted by a shader should not acquire an independent `.metalh`
declaration.

Apple's
[structured-data guidance](https://developer.apple.com/documentation/realitykit/passing-structured-data-to-a-metal-compute-function)
uses the same focused C-header, bridging-header, and direct Metal-include
pattern. If these layouts later move from the app into a Swift package, follow
the C-module boundary described in
[TN3133](https://developer.apple.com/documentation/technotes/tn3133-packaging-a-renderer)
instead of exporting the app's bridging header as a package API. A framework
should likewise expose the C declarations through its Clang module or umbrella
header rather than exporting an app bridging header.

A shared source declaration is also distinct from shared mutable storage.
`FrameResources` owns the CPU-written `MTLStorageModeShared` buffers and writes
the imported records into a frame slot only when that slot is no longer in
flight. The resource store retains those buffers, and the residency manager
makes their allocations resident. The screen's `MetalInFlightSubmission`
retains its complete submitted resource graph until queue feedback arrives,
then calls `markAvailable()` to release the frame slot's availability semaphore.
This reuse gate, rather than object lifetime or residency alone, prevents the
CPU from overwriting bytes still consumed by the GPU. The header defines byte
meaning; frame ownership, residency, and synchronization still define when
those bytes are safe to access. See Apple's
[resource fundamentals](https://developer.apple.com/documentation/metal/resource-fundamentals)
for the underlying Metal resource model.

Continue testing alignment, size, stride, every field offset, buffer lengths,
per-instance address selection, and representative shader consumption.
A common header removes duplicate declarations, but these tests still protect
the allocation, addressing, binding, initialization, and consumption contracts
around that declaration.

## Device-Scoped Metal Resources

`MetalResourceStore` is the current device-scoped root for backend resources.
One store owns exactly one `MTLDevice`; selecting a different device requires a
different store and a different set of compiled and allocated objects.

The current macOS 27 target uses the Metal 4 family directly. It has no legacy
`MTLCommandQueue` or legacy command-encoder fallback. This target constraint
allows the store and frame path to require `MTL4CommandQueue`,
`MTL4CommandBuffer`, `MTL4CommandAllocator`, `MTL4RenderCommandEncoder`, and
`MTL4ArgumentTable` throughout. A device that cannot create the Metal 4 queue
causes resource-store construction to fail; the view coordinator retains that
failure instead of selecting the legacy Metal family.

The store eagerly creates the resources required by the current renderer:

- an `MTL4Compiler` and `MTL4CommandQueue`
- one ``MetalRequiredResources`` value containing the engine shader library,
  four compiled Metal 4 pipelines, opaque depth state, and three argument
  tables as nonoptional typed handles
- decoded models resolved from backend-neutral `MeshID` values
- validated authored descriptions resolved from backend-neutral `MaterialID`
  values
- the fixed frame-resource ring and its PBR/presentation parameter buffers
- the PBR scene, normal diagnostic, tone-mapped presentation, and linear
  diagnostic pipelines

``MetalRequiredResources`` keeps the string-named shader entry points inside
the store's fallible construction boundary. Successful store construction
therefore proves that the complete fixed set exists, and ``MetalFrameEncoder``
retains those handles directly rather than replaying an impossible cache-miss
failure while preparing or encoding a frame.
Catalog or renderer construction failures remain observable through the
`MetalSceneView` coordinator's latest render error rather than being discarded
when the bridge cannot create a renderer.

Future vertex layouts, function constants, blend state, and attachment variants
that expand this small fixed set should become explicit required properties or
deliberately modeled dynamic variant keys instead of silently sharing a
pipeline definition.

## View-Independent Metal Frame Encoding

``MetalFrameEncoder`` owns the backend work used by the screen renderer:

- authored-material preflight for the bounded submitted instance prefix
- the fixed `rgba16Float` scene, `depth32Float` depth, and `bgra8Unorm_srgb` destination format contract
- `FrameResources` buffer packing
- model, diagnostic, depth, and presentation pipeline and argument-table selection
- the ordered HDR scene and presentation pass
- model draw iteration and binding

The caller supplies one prepared ``RenderFrame``, caller-owned scene-color, depth, and destination textures with matching positive dimensions and formats, an available `FrameResources` slot, and an already-begun `MTL4CommandBuffer`. Scene and presentation encoder creation propagate the closed ``MetalFrameEncoderError`` domain through typed throws; no Boolean or result object duplicates that local control flow. The encoder records work but does not sample live presentation state, choose or wait for a frame-ring slot, acquire an `MTKView` or `CAMetalDrawable`, begin, end, or submit a command buffer, manage target residency or completion feedback, present an image, or decide whether an error is terminal.

``MetalRenderer`` owns those screen-specific policies: latest-presentation sampling, projection through the published snapshot camera, ring-slot arbitration, drawable and depth acquisition, target and residency hookup, queue submission and feedback lifetime, drawable presentation, and terminal screen error state. Construction also resolves the required presentation sRGB color space before the renderer becomes usable. The screen passes `MetalResourceStore.defaultFrameCount`; compiled target formats remain ``MetalFrameEncoder`` contracts.

## Metal 4 Residency Sets

Residency and Swift object ownership are separate responsibilities. The resource
store strongly retains models, buffers, pipeline states, and other backend
objects. `MetalResidencyManager` groups only objects conforming to
`MTLAllocation` so the Metal 4 command queue can ensure those allocations are
resident when submitted work uses them.

The current implementation uses two queue-wide, resource-store-owned sets:

- **Static Render Assets** contains immutable model vertex and index buffers.
- **Render Frame Buffers** contains the CPU-written transform/material instance,
  light-only PBR-scene, and presentation-parameter buffers in the frame ring.

In addition, each reusable frame slot lazily owns one drawable-sized HDR scene
target and one committed residency set containing that target. The set is
attached to the exact command buffer that uses it, and the in-flight submission
token retains the target and set until queue feedback completes. Resize replaces
a slot's target only after that slot is no longer in flight.

Those are caller lifetime choices, not responsibilities hidden inside ``MetalFrameEncoder``.

MetalKit and Core Animation continue to own their drawable-related allocations.
Their view and layer residency sets are registered with the command queue when
the `MTKView` is configured rather than copied into an engine-owned set.

Pipeline states, shader libraries, depth-stencil states, compilers, and argument
tables are retained as nonoptional typed resources and handles but are not
`MTLAllocation` values and do not belong in these residency sets.
## Proposed Long-Term Frame Shape

A likely long-term frame flow is:

1. simulation systems update ECS state
2. the Simulation Runtime publishes a completed `SimulationPresentationSnapshot`
3. the Render Runtime selects the latest completed presentation
4. the Render Runtime projects the scene and published camera into render items
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
- ``System`` implementations continue to operate on ECS data
- the Simulation Runtime publishes its own presentation snapshot without requiring a Render Runtime
- the current render path projects published state and its camera instead of reading live simulation objects
## Topics
### Architecture
- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
- <doc:PBR-Implementation-Plan>
### Related Symbols
- ``Engine``
- ``World``
- ``ComponentStore``
