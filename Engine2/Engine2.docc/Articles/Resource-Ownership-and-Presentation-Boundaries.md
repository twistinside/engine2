# Resource Ownership and Presentation Boundaries

This article captures the intended boundary between simulation state, presentation state, and backend rendering state in Engine2.
See <doc:Runtime-Architecture> for the canonical top-level ownership model and runtime-boundary vocabulary.
See <doc:Runtime-Communication> for snapshot and event publication ownership.
See <doc:Game-Content-Architecture> for the distinction between packaged game assets, ECS resources, and runtime-owned backend resources.
## Status

Partially implemented.

The current code already reflects the core ownership split:
- ``InputRuntime`` owns mutable physical input state, maps it to context-free semantic intent, and publishes immutable `InputSnapshot` values
- ``MetalScenePlatformView`` is the single AppKit `MTKView` render surface and a thin physical-event ingress adapter; it owns no semantic mapping, gameplay policy, or rendering logic
- ``World`` owns simulation-scoped state such as `camera` and fixed-tick `input`
- device-scoped backend objects remain owned by ``MetalResourceStore``; frame-sized Metal targets remain Render-owned by their slot owners
- ``MetalFrameEncoder`` owns reusable frame preparation and command encoding without owning a view, drawable, target lifetime, queue submission, or presentation
- ``MetalRenderer`` owns the current screen's source sampling, frame-ring arbitration, drawable acquisition, submission, presentation, and terminal error policy
- ``RenderFrame`` acts as the current translation boundary from Simulation presentation into private render data

There is no concrete `RenderRuntime` lifecycle type yet. ``RealtimeAssembly``
supplies the screen's catalog and read-only presentation source to
``MetalSceneView``. Its coordinator owns ``MetalRenderer`` for the view's
lifetime, and the renderer retains ``MetalResourceStore``. References to the
Render Runtime below describe the intended top-level owner of this implemented
object graph. ``MetalInFlightSubmission`` can retain the submitted portion of
that graph beyond view teardown until queue feedback arrives.

## Resource Scope Follows Runtime Ownership

Engine2 should treat `resource` as a storage, cardinality, and lifetime role inside an owning runtime, not as the primary naming vocabulary for every type.
Concrete types should still describe what they are responsible for.
``MetalResourceStore`` and ``InputState`` communicate more than a generic
resource-bag name.
The important questions are who owns the value, how long it lives, and whether it represents per-entity state. The number of systems that access a value does not determine whether it is a resource.
In practice:
- `World` can own simulation-scoped resources that affect gameplay or simulation behavior
- a runtime can own long-lived services and caches that never belong in `World`
- a data structure used only by one system can remain private system state
- long-lived shared storage written by one system and read by another can become a typed Simulation Runtime or World resource
- rendering types should keep backend-specific resources inside the current render layer or a future Render Runtime
This lets the engine use resource storage patterns without collapsing every runtime into a single undifferentiated resource bag.

Do not connect runtimes through process-global mutable resources. Globals hide ownership, make multiple runtime instances difficult, contaminate tests, and make lifecycle and concurrency behavior implicit. The App should construct explicit dependencies, while peer runtimes communicate through immutable boundary values and focused request/result capabilities.

## Input Ownership Stops at a Semantic Snapshot

Platform input and Simulation input have different owners and cadences. In the current real-time topology, ``MetalScenePlatformView`` is the single AppKit `MTKView` used by the screen renderer and the thin adapter that forwards host `InputEvent` values to ``InputRuntime`` through `InputEventSink`. The adapter does not map controls, make gameplay decisions, mutate `World`, call the Simulation Runtime, or perform rendering. ``InputRuntime`` owns the physical device state and its configured physical-to-context-free-semantic mapping, then publishes the latest immutable `InputSnapshot` through `InputSnapshotSource`. `MetalRenderer` receives neither the physical events nor the semantic snapshot.

In the real-time assembly, ``RealtimeAdvanceDriver`` captures a transition baseline immediately at start, resume, or synchronization, then samples the latest semantic snapshot once per exact batch. It carries those immutable values together as rebase-then-ingest when both exist. ``SimulationRuntime`` applies the assignment only after cursor validation, and ``Engine`` consumes transient input only when the first requested fixed step actually begins. ``InputState`` remains the World resource for held translation and interaction intent, interval-local camera and selection commands, consumer baselines, and cleanup. ``CameraInputSystem`` interprets camera commands against authoritative camera state, while content behavior systems interpret translation, interaction, and selection against ECS selection and control state. The real-time screen does not interpret input separately and uses exactly the camera in the latest completed ``SimulationPresentationSnapshot``. Snapshot revisions prevent the same publication from being consumed as new Simulation input twice. Within one publisher session, cumulative camera-orbit and camera-zoom totals plus the selection-press count let Simulation derive the complete semantic interval between sampled revisions without requiring Input and Simulation to advance together.

This latest-value boundary does not retain an ordered history of discrete transitions. The platform `InputEvent` type is ingress, not a published event journal. Replay or transition-sensitive consumption will require a separate explicit recording or ordered-event design.
## World Owns Abstract Presentation State

`World` is allowed to contain presentation-relevant state as long as that state remains abstract and engine-facing.

Current world-owned presentation data includes:

- `MeshID` and `MaterialID`
- the Simulation-authoritative camera

Future backend-neutral state may include visibility or render-style values.
That kind of data is still part of the game's authoritative state. It describes how an entity should appear, not how Metal happens to draw it.
What should not live in `World` are backend-specific objects such as:

- `MTLDevice`
- `MTL4CommandQueue`
- `MTLRenderPipelineState`
- `MTLBuffer`
Those objects exist to satisfy rendering. The current render layer owns them,
and a future Render Runtime should preserve that boundary.
## Backend State Belongs to Render

The proposed Render Runtime is not the owner of gameplay truth. It should own
Metal-specific state and any caches or services that exist only to make draw
submission work, including:

- device and queue setup
- pipeline compilation and caching
- GPU resource allocation
- Metal 4 residency sets grouped by allocation lifetime
- pass configuration
- drawable or target encoding
This keeps backend lifetime concerns and platform-specific details isolated from simulation code. The current screen path implements that ownership through `MetalSceneView.Coordinator`, ``MetalRenderer``, ``MetalResourceStore``, and their focused collaborators rather than through one `RenderRuntime` object.

The current implementation now separates reusable encoding from output orchestration. ``MetalFrameEncoder`` owns authored-material preflight, the fixed scene/depth/destination format contract, frame-buffer packing, pipeline and argument-table selection and binding, the HDR pass, and model draws. ``MetalResourceStore`` and ``MetalRequiredResources`` own the underlying device-scoped handles. The encoder's caller supplies the textures, an available `FrameResources` slot, and an already-begun Metal 4 command buffer. The caller also owns target allocation and retention, residency hookup, command-buffer lifecycle and submission, feedback, readback or presentation, and error policy.

For the screen, ``MetalRenderer`` is that caller and remains tied to MetalKit cadence and drawable presentation.
## Snapshot Publication Is the Translation Boundary

The current code separates simulation publication from render projection:

1. the Simulation Runtime publishes a completed, backend-neutral `SimulationPresentationSnapshot`
2. `MetalRenderer` samples the latest value at screen draw cadence
3. the current screen calls `RenderFrame(projecting:)`, so the frame uses `snapshot.camera` exactly
4. `RenderFrame` projects the scene and published camera into a private value while preserving the Simulation cursor
5. Render resolves abstract identities into its privately owned backend resources
6. an output-specific caller supplies targets and submission lifetime to ``MetalFrameEncoder``

`World` should not directly emit Metal-facing structs as part of its core API, and the renderer should not read live gameplay state during drawing. The current render layer owns the destination projection; a future Render Runtime should retain that ownership while Simulation remains unaware of render-specific fields and backend choices.

## Draw Cadence Is Separate From Simulation Cadence

Simulation stepping and drawing should not be treated as the same event.
Under a fixed-step engine:
- simulation may advance zero, one, or multiple steps before a draw
- a draw may happen even when no new simulation tick has occurred
- presentation should consume the latest completed render data rather than reach back into live simulation state
In a Metal view-driven application, the view still dictates when a drawable is available. That should control when the renderer submits work, not when gameplay state advances.

That display rule belongs to ``MetalRenderer``, not ``MetalFrameEncoder``. The encoder deliberately has no policy for source selection, surface availability, frame-slot arbitration, queue submission, completion, presentation, or readback.

The current presentation model is:

1. simulation updates `World`
2. Simulation publishes a new immutable simulation presentation snapshot
3. `MetalRenderer` samples and projects the latest available value when `MTKView` requests a draw
4. ``MetalFrameEncoder`` records the private ``RenderFrame`` into caller-owned targets
5. `MetalRenderer` submits the command buffer and presents the drawable

This keeps simulation deterministic while still fitting a display-driven render loop.

A future retained Render front/back buffer is an optimization and isolation
boundary, not part of the current screen implementation.

## Related Direction

This boundary preserves the current engine direction:
- `World` remains authoritative for simulation and abstract presentation state
- ``System`` implementations continue to operate on ECS data in hot paths
- the Simulation Runtime publishes its own presentation snapshot without depending on a Render Runtime
- the current render path owns a private projection of authoritative game state rather than a second gameplay model
## Topics
### Architecture
- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
### Related Symbols
- ``World``
