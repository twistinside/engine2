# Resource Ownership and Presentation Boundaries
This article captures the intended boundary between simulation state, presentation state, and backend rendering state in Engine2.
See <doc:Runtime-Architecture> for the canonical top-level ownership model and runtime-boundary vocabulary.
See <doc:Runtime-Communication> for snapshot and event publication ownership.
See <doc:Game-Content-Architecture> for the distinction between packaged game assets, ECS resources, and runtime-owned backend resources.
## Status
Partially implemented.
The current code already reflects the core ownership split:
- ``InputRuntime`` owns mutable platform input collection state and publishes immutable `InputSnapshot` values
- ``World`` owns simulation-scoped state such as `camera` and fixed-tick `input`
- render-specific Metal objects remain owned by ``MetalResourceStore``
- ``MetalFrameEncoder`` owns reusable frame preparation and command encoding without owning a view, drawable, target lifetime, queue submission, or presentation
- ``MetalRenderer`` owns the current screen's source sampling, frame-ring slot, drawable, submission, presentation, and terminal error policy
- ``POffscreenRenderTarget`` defines exact asynchronous request/outcome ownership without exposing backend resources
- ``MetalOffscreenRenderRuntime`` owns dedicated one-slot Metal resources, request-scoped targets, queue-feedback lifetime, and detached raw readback without owning a source, Simulation advancement, view, drawable, or artifact encoder
- ``JPEGArtifactEncoder`` owns no mutable resource or Runtime lifecycle; it transforms detached raw results into detached JPEG artifacts while preserving exact provenance
- ``OfflineCaptureAssembly`` hides its Simulation and Render Runtimes behind one ``POfflineCaptureTarget`` so ``OfflineCaptureCoordinator`` remains the sole effective advance authority
- ``RenderFrame`` acts as the current translation boundary into presentation data
## Resource Scope Follows Runtime Ownership
Engine2 should treat `resource` as a storage, cardinality, and lifetime role inside an owning runtime, not as the primary naming vocabulary for every type.
Concrete types should still describe what they are responsible for, such as:
- `MetalContext`
- `RenderResourceCache`
- `MeshLibrary`
- `SpawnQueue`
- `DebugSettings`
The important questions are who owns the value, how long it lives, and whether it represents per-entity state. The number of systems that access a value does not determine whether it is a resource.
In practice:
- `World` can own simulation-scoped resources that affect gameplay or simulation behavior
- a runtime can own long-lived services and caches that never belong in `World`
- a data structure used only by one system can remain private system state
- long-lived shared storage written by one system and read by another can become a typed Simulation Runtime or World resource
- rendering types should keep backend-specific resources inside the Render Runtime
This lets the engine use resource storage patterns without collapsing every runtime into a single undifferentiated resource bag.

Do not connect runtimes through process-global mutable resources. Globals hide ownership, make multiple runtime instances difficult, contaminate tests, and make lifecycle and concurrency behavior implicit. The App should connect runtimes through explicit immutable boundary values.

## Input Ownership Stops at a Snapshot

Platform input and simulation input have different owners and cadences. ``InputRuntime`` maintains private collection state and publishes its latest immutable `InputSnapshot` through `PInputSnapshotSource`. In the current real-time topology, `InputMetalView` submits host `InputEvent` values through the ``RealtimeAssembly`` `PInputEventSink`; the assembly explicitly fans them to ``InputRuntime`` and one ``ScreenViewpointController``. The platform adapter and assembly connector do not mutate `World` or call the Simulation Runtime.

In the real-time assembly, ``RealtimeAdvanceDriver`` captures a transition baseline immediately at start, resume, or synchronization, then samples the latest snapshot once per exact batch. It carries those immutable values together as rebase-then-ingest when both exist. ``SimulationRuntime`` applies the assignment only after cursor validation, and ``Engine`` consumes transient input only when the first requested fixed step actually begins. `InputState` remains a World resource for Simulation-facing held state, fixed-tick history, transient derivation, cleanup, and future gameplay action mapping. Output-specific orbit and zoom are no longer installed in the default Simulation schedule; the screen controller owns that presentation interpretation. Snapshot revisions prevent the same publication from being consumed as new Simulation input twice. Within one publisher session, cumulative pointer-motion and scroll totals let Simulation derive the complete interval between sampled revisions without requiring Input and Simulation to advance together.

This latest-value boundary does not retain an ordered history of discrete transitions. The platform `InputEvent` type is ingress, not a published event journal. Replay or transition-sensitive consumption will require a separate explicit recording or ordered-event design.
## World Owns Abstract Presentation State
`World` is allowed to contain presentation-relevant state as long as that state remains abstract and engine-facing.
Examples of world-owned presentation data include:
- mesh handles
- material handles
- camera settings
- visibility flags
- render styles such as opaque, transparent, additive, or debug
That kind of data is still part of the game's authoritative state. It describes how an entity should appear, not how Metal happens to draw it.
What should not live in `World` are backend-specific objects such as:
- `MTLDevice`
- `MTLCommandQueue`
- `MTLRenderPipelineState`
- `MTLBuffer`
Those objects exist to satisfy rendering and should remain owned by the Render Runtime.
## The Render Runtime Owns Backend State
The Render Runtime is not the owner of gameplay truth.
It should own Metal-specific state and any caches or services that exist only to make draw submission work, including:
- device and queue setup
- pipeline compilation and caching
- GPU resource allocation
- Metal 4 residency sets grouped by allocation lifetime
- pass configuration
- drawable or target encoding
This keeps backend lifetime concerns and platform-specific details isolated from simulation code.

The current implementation now separates reusable encoding from output orchestration. ``MetalFrameEncoder`` owns authored-material preflight, the fixed scene/depth/destination format contract, frame-buffer packing, pipelines and argument tables, the HDR pass, and model draws. Its caller supplies the textures, an available `FrameResources` slot, and an already-begun Metal 4 command buffer. The caller also owns target allocation and retention, residency hookup, command-buffer lifecycle and submission, feedback, readback or presentation, and error policy.

For the screen, ``MetalRenderer`` is that caller and remains tied to MetalKit cadence and drawable presentation. ``MetalOffscreenRenderRuntime`` is the production exact caller. It owns a dedicated `MetalResourceStore(frameCount: 1)`, ``MetalFrameEncoder``, configurable safety limits, one single-flight request gate, request-local destination/depth targets and residency, command submission, and queue-feedback lifetime. It has no `MTKView` or `CAMetalDrawable` and never samples a source or advances Simulation.

The offscreen Runtime strictly projects every requested presentation fact and resolves every requested model and material before mutable GPU work. It refuses malformed viewpoints, malformed presented entities, and frames above the 256-instance capacity rather than returning an ambiguous partial image. It also fails preparation for a missing model or incomplete drawable indexed geometry instead of inheriting the screen's tolerant draw omission. Its submission token retains the complete referenced Metal object graph until real feedback and releases the sole frame slot exactly once. A GPU feedback error latches the original terminal cause so later requests fail without reusing uncertain queue state.
## Snapshot Publication Is the Translation Boundary
The current code separates simulation publication from render projection:

1. the Simulation Runtime publishes a completed, backend-neutral `SimulationPresentationSnapshot`
2. the Render Runtime selects the latest value according to its own cadence
3. an optional `PRenderViewpointSource` resolves an output-specific ``RenderViewpoint`` against the snapshot camera as its exact default
4. ``RenderFrame.project(from:viewpoint:)`` projects the scene and selected camera into a private value while preserving Simulation and optional viewpoint attribution
5. Render resolves abstract identities into its privately owned backend resources
6. an output-specific caller supplies targets and submission lifetime to ``MetalFrameEncoder``

`World` should not directly emit Metal-facing structs as part of its core API, and the renderer should not read live gameplay state during drawing. The Render Runtime owns the destination projection while Simulation remains unaware of render-specific fields and backend choices.

The exact offscreen branch replaces steps 2–3 with one immutable ``OffscreenRenderRequest`` that already contains the completed ``SimulationPresentationSnapshot``, explicit ``RenderViewpoint``, and settings. ``POffscreenRenderTarget`` returns a correlated outcome rather than consulting replaceable latest-value slots. A successful result owns detached, tightly packed, top-left, opaque BGRA8-sRGB bytes and echoes the request identity, source cursor, complete viewpoint, and settings.

``JPEGArtifactEncoder`` consumes that detached value afterward. Its ``RenderedImageArtifact`` owns independent encoded data and repeats the exact request, cursor, complete viewpoint, and render settings together with the JPEG settings. Because the encoder is stateless and nonisolated, the caller selects its execution context. Encoding failure does not affect either Runtime and can retry from the same raw result without ticking or rerendering.
## Draw Cadence Is Separate From Simulation Cadence
Simulation stepping and drawing should not be treated as the same event.
Under a fixed-step engine:
- simulation may advance zero, one, or multiple steps before a draw
- a draw may happen even when no new simulation tick has occurred
- presentation should consume the latest completed render data rather than reach back into live simulation state
In a Metal view-driven application, the view still dictates when a drawable is available. That should control when the renderer submits work, not when gameplay state advances.

That display rule belongs to ``MetalRenderer``, not ``MetalFrameEncoder``. The encoder can record the same production frame work into matching caller-owned offscreen targets, but it deliberately has no policy for source selection, surface availability, frame-slot arbitration, queue submission, completion, presentation, readback, or artifact encoding. ``MetalOffscreenRenderRuntime`` supplies the implemented exact target, submission, cancellation, completion, and raw-readback policy without adding those responsibilities to the encoder.

This display-driven rule is not the only presentation configuration. The implemented ``OfflineCaptureCoordinator`` requests one exact Simulation advancement, passes only its returned immutable snapshot plus the request's explicit viewpoint and settings to ``POffscreenRenderTarget``, validates the result's provenance, and waits for JPEG encoding before completing. The coordinator owns that directed workflow; Render still does not own or mutate Simulation.

``OfflineCaptureAssembly`` exposes neither Runtime, so another caller cannot bypass serial coordination and become a second advance authority. Every post-advance outcome retains the committed ``SimulationAdvanceResult``; post-render cancellation and JPEG failure retain the raw result as well. This is explicit value ownership, not rollback or automatic retry. A dedicated render actor or worker, pooled targets, HDR master and sample accumulation, PNG encoding, expanded artifact metadata, persistence, and `ArtifactSink` remain proposed. See <doc:Runtime-Configurations-and-Advancement>.
The intended presentation model is:
1. simulation updates `World`
2. Simulation publishes a new immutable simulation presentation snapshot
3. Render projects the latest available value into private render state
4. private front and back render frames swap
5. the Render Runtime draws from the latest completed value when presentation requests a draw
This keeps simulation deterministic while still fitting a display-driven render loop.
## Practical Naming Guidance
Prefer domain names for concrete types and reserve `PResource` for protocol or storage classification. Snapshot values use a descriptive `Snapshot` suffix rather than the `S` prefix, which remains reserved for ECS systems. Runtime types use the full `Runtime` suffix.
For example:
- prefer `MetalContext` over `RMetal`
- prefer `RenderResourceCache` over a generic render resource bag
- prefer `MeshLibrary` or `MaterialRepository` over unnamed storage wrappers
That keeps architectural intent readable while still allowing typed resource access patterns where they are useful.
## Related Direction
This boundary preserves the current engine direction:
- `World` remains authoritative for simulation and abstract presentation state
- ``PSystem`` implementations continue to operate on ECS data in hot paths
- the Simulation Runtime publishes its own presentation snapshot without depending on a Render Runtime
- the Render Runtime owns a private projection of authoritative game state rather than a second gameplay model
## Topics
### Architecture
- <doc:Runtime-Architecture>
- <doc:Runtime-Configurations-and-Advancement>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
### Related Symbols
- ``World``
- ``PResource``
