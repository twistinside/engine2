# Engine2 AGENTS Guide
## Repo Summary
Engine2 is a compact Swift ECS experiment with a small but increasingly coherent runtime shape. The project is moving toward a hybrid model:
- ECS component stores are the simulation source of truth.
- Entity objects are ergonomic, typed facades over ECS state.
- Capability protocols such as `PMovable` and `PPositionable` are kept as the game-facing/UI-facing surface.
- Systems should operate directly on component stores in hot paths.
This repo is still early, but several core paths now exist. Preserve direction and intent when filling in missing pieces.

## Runtime Architecture
The proposed top-level application architecture is documented in `Engine2/Engine2.docc/Articles/Runtime-Architecture.md`.

Use these terms consistently:
- A **Runtime** is a long-lived top-level application object with its own state, lifecycle, cadence, and explicit boundaries. Runtime types use the full `Runtime` suffix, such as `InputRuntime`, `SimulationRuntime`, and `RenderRuntime`.
- The App owns and wires runtimes. Runtimes do not discover one another through global mutable state.
- The **Simulation Runtime** is authoritative for gameplay state and contains `Engine`, `World`, ECS resources, and ECS systems. It is first among peers semantically, but it does not own the lifecycles of other runtimes.
- An ECS **System** is scheduled logic inside the Simulation Runtime, not a top-level runtime. Keep the `S` prefix reserved for systems.
- A **Snapshot** is an immutable point-in-time boundary value. Snapshot types use a descriptive `Snapshot` suffix rather than an `S` prefix.
- An **Event** is an immutable fact published within a runtime's authority. Optional peer runtimes may observe it; the publisher must remain correct when no consumer exists.
- Prefer snapshots and events for peer-runtime choreography. Directed request/result workflows should represent deliberate dependencies and normally be coordinated by the App.
- Runtimes may differ in usefulness without peers. Independence means explicit ownership and lifecycle safety, not equal standalone capability.
- There is no universal frame cadence. Input delivery, fixed Simulation Runtime ticks, render frames, and future Audio/Network/Storage work may advance independently.

Current types implement part of this direction:
- `InputRuntime` owns platform input state and publishes its latest immutable `InputSnapshot` through `PInputSnapshotSource`; platform adapters submit `InputEvent` values through `PInputEventSink`.
- `SimulationRuntime` owns one authoritative session, `Engine`, and `World`; it accepts exact cursor-qualified advance requests and does not own wall-clock cadence or a live Input source.
- `RealtimeAdvanceDriver` is an App-owned connection object that samples wall time and the configured latest Input publication, then submits immutable assignments through `PSimulationAdvanceTarget`.
- `RealtimeConfiguration` composes Input, Simulation, the real-time driver, and one App-owned `ScreenViewpointController`. `ManualConfiguration` composes caller-driven Simulation without Input or an automatic cadence.
- `SimulationRuntime.fixedTimeStep` is the sole production definition of one tick's duration. Top-level configurations cannot redefine it, and `Engine` has no competing wall-clock or partial-schedule path.
- `InputMetalView` submits host `InputEvent` values to `RealtimeAssembly`. That assembly currently performs a deliberate hard-coded fan-out to `InputRuntime` and its screen viewpoint controller; it does not call the Simulation Runtime or mutate `World`.
- `ScreenViewpointController` is an ordinary App-owned presentation controller, not a Runtime. It can revise one screen's free-orbit viewpoint while Simulation is paused.
- `SimulationPresentationSnapshot` is the Simulation Runtime-owned latest completed presentation value. Its camera is the publisher-authored default when an output supplies no override.
- `RenderViewpoint` is an immutable output-specific camera value with stable identity and monotonic revision. `RenderFrame` is the Render Runtime-owned private projection that preserves the source Simulation cursor plus optional explicit-viewpoint identity and revision.
- `MetalFrameEncoder` owns view-independent Metal frame preparation and encoding against caller-owned targets, frame resources, and an already-begun command buffer.
- `MetalSceneView` and `MetalRenderer` cover the screen adapter responsibilities. `MetalRenderer` samples Simulation presentation and viewpoint sources, arbitrates the frame ring and drawable, submits, presents, and owns screen error policy; it delegates reusable GPU encoding to `MetalFrameEncoder` and never reads live `World` state.
- `POffscreenRenderTarget` is the backend-neutral exact asynchronous render capability. Its request carries one immutable Simulation presentation snapshot, one explicit viewpoint, and render settings; its outcome preserves expected refusals, accepted-request failures, post-submission cancellation, or a provenance-rich detached image.
- `MetalOffscreenRenderRuntime` is the first production offscreen Runtime. It owns dedicated one-slot Metal resources, enforces a single-flight busy gate and configurable size limits, and drives `MetalFrameEncoder` without sampling sources, advancing Simulation, or acquiring a view or drawable.
- `JPEGArtifactEncoder` is a stateless, nonisolated CPU transformation above the raw Render result. It preserves request, Simulation-cursor, complete-viewpoint, and render-settings provenance in a detached JPEG artifact; a failed encoding can be retried from the same raw result without advancing or rerendering.
- `OfflineCaptureConfiguration` constructs one deliberately closed serial topology containing Simulation, exact offscreen Render, and `OfflineCaptureCoordinator`. Its assembly exposes only the initial cursor and `POfflineCaptureTarget`; the coordinator is the sole effective advance authority and retains exactly the initial or last completed presentation. The target supports at-most-once advance capture and mandatory-cursor current capture through one gate, shared exact Render validation, and JPEG encoding outside the actor.
- `SimulationAdvanceResult` enforces one internally coherent completed session, cursor range, positive completed count, and final presentation cursor at construction. `OfflineCaptureCoordinator` additionally correlates that result to its retained starting cursor and submitted expected cursor/count before rendering. A coherent but request-mismatched completion becomes a typed `advanceResultMismatch`; because work may already have committed, its final snapshot becomes the retained current presentation.
- `AgentSessionConfiguration` is the implemented transport-neutral, live-process agent recipe. Its `AgentSessionAssembly` privately retains an `OfflineCaptureAssembly` and gives `AgentSessionCoordinator` only `POfflineCaptureTarget`, preserving the offline coordinator as the sole effective Simulation advance authority. `AgentCaptureSource` selects bounded `.advance` or non-advancing `.current`, and both complete payloads share one request-identity, idempotency, retention, overlap, and lifecycle lane. The agent assembly exposes only the agent-session identity, initial cursor, first request identity, `PAgentSessionTarget`, and drain-before-close lifecycle. New non-reflexive payloads are rejected before acceptance, and accepted high-water remains explicit even when result retention or the next representable sequence does not.

The current screen fan-out is intentionally one concrete connection, not a generalized routing framework. Multi-source input, typed routes and route epochs, multi-window/output bindings, Simulation observer anchors, artifact persistence/sinks, PNG and HDR accumulation, dedicated Render workers, and an actual MCP Runtime with transport, authentication, wire DTOs, durable idempotency, controls, and structured observations remain proposed. Agent current capture produces an exact visual artifact; it is not structured observation. Physical and semantic controls remain future until a typed gameplay consumer exists.

Do not rename or wrap existing types solely to match the vocabulary. Introduce a runtime boundary when it creates concrete ownership, lifecycle, cadence, or testing value.

## Game Content Architecture
The proposed consumer-content boundary is documented in `Engine2/Engine2.docc/Articles/Game-Content-Architecture.md`.

Use these terms and constraints consistently:
- **Game Content** is consumer-defined game code, descriptions, catalogs, and assets used to construct and configure runtimes. It is not a runtime and has no independent cadence or lifecycle.
- The App is the composition root. It constructs Game Content, then supplies the relevant portions to independently constructed runtimes.
- Use **Asset** for packaged source content such as models, textures, sounds, animations, and levels. Do not conflate assets with ECS or runtime resources, even though SwiftPM calls bundled files resources.
- Game Content owns the exhaustive, strongly typed, backend-neutral identities for the entities and assets it defines, such as the current `MeshID` and `MaterialID` and a future `SoundID` enum. Runtimes may carry and resolve those values, but they do not own the content vocabulary. Do not store raw `MTLBuffer`, `MTKMesh`, decoded audio, or other backend objects in ECS or Game Content.
- Runtimes privately resolve content assets into backend resources. Game Content does not own runtime caches, GPU allocations, decoded audio, or runtime lifecycle.
- Continuous presentation can be described through abstract ECS state and snapshots. Ephemeral presentation should normally derive from Simulation Runtime events plus consumer-supplied presentation rules.
- Consumer Game Content may eventually define entities, components, optional behaviors, world builders, render/audio descriptions, asset catalogs, and event-presentation mappings through deliberate public Engine2 APIs.
- The Simulation Runtime owns invariant systems and their foundational schedule. Future Game Content behavior must enter through controlled extension points rather than replacing that foundation.
- The runtime performing work owns the interface it consumes. Simulation owns `PWorldBuilder`; Render owns `RenderFrame` and its projection from the publisher-owned `SimulationPresentationSnapshot` contract.
- Do not make every current type public. Design the smallest coherent extension surface needed by external content while keeping engine storage and backend internals encapsulated.
- The current fixed component-store list in `World` and fixed capability translation in `World.add(_:from:)` are the largest limitations on external consumer-defined components. Preserve strong typing and avoid solving this with a closed component enum or process-global registry.

Current example ownership:
- `Ball`, `BasicWorldBuilder`, and `BasicGameContent` are example Game Content.
- `Ball.usda` and `Ball.usdz` are example Game Content render assets, not reusable Render Runtime implementation.
- `ModelShaders.metal` is Render Runtime backend implementation unless a future explicit shader/material extension point makes part of it consumer content.
- Debug panes and app commands are example App tooling.
## Code Quality
- Never add Xcode-style file header comments that repeat a filename or project name or record who created a file, when it was created, or a boilerplate copyright notice. Remove these headers whenever you encounter them.
- Give production types meaningful `///` documentation comments that make Xcode Quick Help useful. Explain the type's role, ownership, important invariants, and intended boundary rather than merely restating its name.
- One type per file is a project rule. Name the file after the type; extensions of that type may remain with it when doing so preserves cohesion.
- Swift is strongly typed. Prefer a domain type whenever an `Int` or `String` would permit meaningless arithmetic, concatenation, or invalid values.
- If a value has a known, finite list of possibilities, use an `enum`.
- Using `String` or a string-backed wrapper in place of an enum for a closed set is heavily discouraged. Any exception must be justified with a code or documentation comment explaining why the vocabulary is genuinely open-ended or why an external API requires strings.
## MCP Tooling Preferences
- Prefer the project-aware Xcode tooling available in the current session for builds, tests, file reads, and other IDE-side actions.
- Prefer the Apple documentation tooling available in the current session for framework and API lookups before falling back to general web search.
## Current Structure
- `Engine2/Simulation Runtime/Engine/ECS/World.swift`
  - Central world object.
  - Owns component stores.
  - `add(_:from:)` translates advertised entity capabilities into component rows and validates that seed values match those capabilities.
  - `reserveEntityID()` currently allocates monotonically increasing indices with generation `0`; generation reuse/destruction is still future work.
- `Engine2/Simulation Runtime/Engine/ECS/Entity.swift`
  - Base `Entity` superclass.
  - Holds `id` and `world`.
  - `InitialState` carries common spawn-time transform and motion seed values.
  - `init(unregisteredID:in:)` is for tests and future reconstruction paths.
  - `init(in:from:)` reserves an ID and registers the entity with `World`.
- `Engine2/Simulation Runtime/Engine/ECS/EntityID.swift`
  - Entity handle with `index` and `generation`.
  - `generation` should remain meaningful; do not silently regress to index-only identity semantics.
- `Engine2/Simulation Runtime/Engine/ECS/ComponentStore.swift`
  - Sparse-set style storage:
    - `dense`: component values
    - `entities`: entity IDs aligned with `dense`
    - `sparse`: entity index -> dense index
  - Lookup re-checks the full `EntityID`, including generation.
  - Use `update(for:_:)` for existing component mutations so systems update the dense row in place instead of rebuilding and reinserting replacement rows.
  - Removal, compaction, richer mutation helpers, and join/query helpers are still missing.
- `Engine2/Simulation Runtime/Engine/Protocol/PComponent.swift`
  - Marker protocol for components.
  - Explicitly `nonisolated` so component `Codable` and `Equatable` value semantics do not inherit the app target's default `MainActor` isolation.
- `Engine2/Simulation Runtime/Engine/Protocol/PResource.swift`
  - Marker protocol for long-lived resource and resource-like storage roles inside an owning runtime or world.
  - Sharing mechanism is not what defines a resource; ownership, lifetime, and non-entity cardinality are the important traits.
- `Engine2/Simulation Runtime/Engine/Protocol/PSystem.swift`
  - Core system protocol used by the engine's ordered execution lists.
- `Engine2/Simulation Runtime/Engine/Protocol/PWorldBuilder.swift`
  - Simulation-owned construction interface for producing fully bootstrapped worlds.
- `Engine2/Simulation Runtime/Engine/Infrastructure/Clock/SystemClock.swift`
  - `SystemClock` provides injectable monotonic elapsed-time sampling to `RealtimeAdvanceDriver`, outside exact Simulation execution and system logic.
- `Engine2/Simulation Runtime/Engine/System/Position/Protocol/*.swift`
  - `PPositionable` exposes a live `position` backed by `World.positionComponents`.
  - `PMovable` exposes live motion state backed by `World.motionComponents`.
  - `POrientable` exposes live `rotation`.
  - `PRotatable` exposes live angular velocity and angular accumulator input.
  - `PScalable` exposes live `scale`.
- `Engine2/Simulation Runtime/Engine/System/Selection/PSelectable.swift`
  - Convenience protocol for entity objects that expose live selection state.
- `Engine2/Simulation Runtime/Engine/System/Position/Component/*.swift`
  - `CPosition`
  - `CMotion`
  - `CRotation`
  - `CAngularVelocity`
  - `CAngularMotionAccumulator`
  - `CScale`
  - `CAcceleration` no longer exists; keep the aggregate accumulator direction.
- `Engine2/Simulation Runtime/Engine/System/Selection/CSelectable.swift`
  - Selection-state component used by `PSelectable` entities and selection UI.
- `Engine2/Simulation Runtime/Engine/System/Input/**/*.swift`
  - `InputState` is the authoritative simulation-facing input resource stored on `World`, populated from `InputSnapshot` only at fixed-step boundaries.
  - `SInputHistory` records compact input history rows for debug UI.
  - `SInputCleanup` clears per-tick transient input after input systems have consumed it.
- `Engine2/Simulation Runtime/Engine/System/Position/System/*.swift`
  - `SAccelerationIntent` emits persistent acceleration intent into `CMotion`'s per-tick accumulator.
  - `SMovement` integrates `CMotion` accumulator input into velocity, moves position, then clears the accumulator.
  - `SRotation` integrates angular accumulator input into angular velocity, advances rotation, normalizes it, then clears the accumulator.
- `Engine2/Simulation Runtime/Engine/*.swift`
  - `Engine` owns exact fixed-step execution and one complete ordered system schedule.
  - Input history, cleanup, acceleration intent, movement, and rotation are invariant members of every completed tick; output viewpoint control remains outside Simulation.
- `Engine2/Simulation Runtime/SimulationRuntime.swift`
  - `SimulationRuntime` owns session bootstrap, exact serialized advancement, explicit input-baseline application, and completed presentation publication above `Engine`.
- `Engine2/Runtime Configuration/Realtime/*.swift`
  - `RealtimeConfiguration` constructs independently owned Input and Simulation Runtimes, one `RealtimeAdvanceDriver`, and one `ScreenViewpointController`.
  - `RealtimeAssembly` owns lifecycle ordering, pause policy, async drain-before-stop/rebuild, lifecycle-generation protection for coordinated Simulation cutovers, and the current hard-coded screen-event fan-out.
  - `RealtimeAdvanceDriver` alone translates elapsed wall time into bounded exact cursor-qualified requests, applies configured overflow treatment, captures transition input baselines plus one later immutable publication per batch, faults on an unexpected authority mismatch, and does not retain an otherwise abandoned assembly between sleeps.
- `Engine2/Runtime Configuration/Realtime/Viewpoint/*.swift`
  - `ScreenViewpointController` owns an optional free-orbit override for one screen. Before the first meaningful gesture, and after reset, it passes through the exact latest Simulation-published default camera.
- `Engine2/Runtime Configuration/Manual/*.swift`
  - `ManualConfiguration` and `ManualAssembly` expose caller-driven exact advancement without Input or a polling task.
- `Engine2/Runtime Configuration/Offline/*.swift`
  - `OfflineCaptureConfiguration` always constructs exactly one authoritative Simulation Runtime, one dedicated `MetalOffscreenRenderRuntime`, and one `OfflineCaptureCoordinator`. It has no Input Runtime, wall-clock cadence, screen surface, or optional-runtime bag.
  - `OfflineCaptureAssembly` exposes only `initialCursor` and the narrow `POfflineCaptureTarget`; it does not expose either Runtime or a second advance capability.
  - `OfflineCaptureCoordinator` is the sole effective advance authority and one-slot exact-presentation holder. It is seeded with Simulation's initial completed snapshot and replaces that value immediately whenever an advance completes, before downstream cancellation or output failure can return. It retains no history.
  - `POfflineCaptureTarget.capture(_:)` submits its supplied positive-step advance request at most once and renders only the returned completed snapshot. `captureCurrent(_:)` requires the retained snapshot's exact cursor and issues no Simulation request or latest-value read. Both paths share one actor-reentrancy gate and common request/cursor/viewpoint/settings/image-size validation.
  - `OfflineCurrentCaptureRequest`, `OfflineCurrentCaptureOutcome`, and `OfflineCurrentCaptureResult` are the non-advancing vocabulary. Pre-render cursor mismatch and cancellation perform no output work; later outcomes retain the exact selected source snapshot, while post-render cancellation and JPEG failure also retain the raw result.
  - Post-submission render cancellation must echo the requested `OffscreenRenderRequestID`. A mismatch returns typed expected/actual identities with the source-appropriate exact `SimulationAdvanceResult` or current `SimulationPresentationSnapshot` instead of accepting corrupted correlation.
  - Production JPEG work runs in an immediately awaited `Task.detached` outside the coordinator actor. That task deliberately does not inherit caller cancellation, so completion wins once encoding starts; the in-flight gate remains set while awaited, making reentrant overlap return `.coordinatorBusy` during encoding too. This is coordinator-selected policy—the standalone `JPEGArtifactEncoder` still selects no executor.
  - Every advance-aware outcome after completed advancement retains the exact `SimulationAdvanceResult`; every current-aware outcome after expected-cursor validation retains the exact snapshot. Cancellation after raw rendering and JPEG failure also retain the `OffscreenRenderResult` for caller-selected encoding retry without another advance or render.
- `Engine2/Runtime Configuration/Agent/*.swift`
  - `AgentSessionConfiguration` privately constructs an `OfflineCaptureAssembly` through `OfflineCaptureConfiguration` and retains that assembly; no Simulation, Render, or lower-level offline capability leaves the agent assembly.
  - `AgentSessionAssembly` exposes only `sessionID`, `initialCursor`, `firstRequestID`, `PAgentSessionTarget`, and `stopAndDrain()`.
  - `AgentCaptureRequest` requires a session-qualified monotonic request identity, an `AgentCaptureSource`, stable render request identity, viewpoint, render settings, and JPEG settings. `.advance(expectedCursor:stepCount:)` has a bounded positive step count and deliberately submits `.none` input; `.current(expectedCursor:)` captures the retained completed presentation without advancing.
  - `AgentSessionCoordinator` owns live-process admission and idempotency above `POfflineCaptureTarget`. `highestAcceptedSequence` is independent of both bounded response retention and the optional next representable sequence, so even an unretained `UInt64.max` response retries as `.resultEvicted` after `successor()` becomes `nil`.
  - Both source choices use one request identity and retention lane. Identical retained requests replay the exact response and artifact; changing source or any source/render payload under one ID conflicts. In-flight duplicates, overlap, sequence gaps, wrong sessions, eviction, invalid payload, closure, and pre-acceptance cancellation are typed. Session and existing identity status are resolved before validating a new payload's reflexive equality, so a malformed retry still reports cached conflict, in-flight conflict, or eviction instead of being misclassified as new invalid work.
  - `AgentSessionLimits` bounds advancing steps, retained-result count, and retained raw/encoded image bytes. The step bound applies only to `.advance`; the named image-byte budget intentionally excludes snapshots and Swift object/collection overhead.
  - A step-limit violation is an accepted, sequence-consuming terminal response and is retained like capture results. `stopAndDrain()` rejects new unique work immediately, lets accepted work finish, and still permits cached identical replay while the live assembly remains retained.
  - Idempotency is scoped to one live process. MCP transport, authentication, transport DTOs, restart-safe journals, physical or semantic controls, structured observation, artifact persistence, reset/load/fork operations, and content identity beyond current artifact provenance remain future work. Current-cursor JPEG capture is visual output, not structured inspection; controls remain absent because no current gameplay system consumes an agent control vocabulary.
- `Engine2/Input Runtime/**/*.swift`
  - `InputRuntime` is the App-owned lifecycle boundary for platform input collection.
  - `PInputEventSink` is the platform-adapter ingress accepted by the runtime.
  - `PInputSnapshotSource` exposes the latest immutable `InputSnapshot` without exposing runtime mutation.
  - `InputRevision` identifies publication sessions and versions. Within one session, cumulative pointer-motion and scroll totals let a slower consumer derive all motion between sampled snapshots without requiring one-to-one cadence.
  - The current `InputEvent` is host ingress, not a published ordered runtime event lane. Ordered discrete transitions and retained replay remain future work.
- `Engine2/Game Content/BasicWorldBuilder.swift`
  - Example Game Content builder that seeds a deterministic six-Ball PBR material grid. Every Ball is quiescent, shares `MeshID.ball`, and selects one smooth, baseline, or rough warm-dielectric or gold-metal `MaterialID`.
- `Engine2/Game Content/Model/MeshID.swift`
  - Game Content-owned enum defining the complete mesh identity vocabulary consumed by simulation presentation state and render catalog lookup.
- `Engine2/Game Content/Material/MaterialID.swift`
  - Game Content-owned enum defining the complete authored material identity vocabulary carried by simulation and resolved privately by Render.
- `Engine2/Game Content/Entity/Ball.swift`
  - Example entity object/facade.
  - Advertises `MeshID.ball` and its per-instance `MaterialID` through `PRenderable`; it does not know the model filename, material factors, or renderer backend.
  - Represents the intended style of game object API more than a finished implementation.
- `Engine2/Simulation Runtime/Engine/System/Rendering/**/*.swift`
  - `CRenderable` stores only abstract `MeshID` and `MaterialID` values in ECS state.
  - `PRenderable` seeds those identities from Game Content entities and exposes their live values.
- `Engine2/Simulation Runtime/Snapshot/*.swift`
  - `SimulationTick` identifies completed fixed steps without wall-clock or render-cadence meaning.
  - `SimulationPresentationSnapshot` publishes immutable camera and entity presentation state through `SimulationRuntime.latestPresentationSnapshot`.
  - `PSimulationPresentationSource` exposes that latest-value publication as a read-only capability without exposing the wider Simulation Runtime API.
  - Ordinary live publication uses latest-value semantics; retained replay history remains an explicit future recorder concern.
- `Engine2/Render Runtime/Asset/*.swift`
  - `RenderAssetCatalog` is the render-owned input contract mapping `MeshID` values to packaged model references and `MaterialID` values to authored `PBRMaterialDescription` values.
- `Engine2/Render Runtime/Frame/*.swift`
  - `RenderFrame.init(projecting:viewpoint:)` converts a `SimulationPresentationSnapshot` into private render instances, uses an explicit viewpoint when supplied, otherwise falls back to the snapshot camera, and preserves optional source-cursor and viewpoint attribution.
  - `RenderFrame.init(exactlyProjecting:viewpoint:)` is the strict request path. It rejects a malformed selected camera or any presented entity with missing position, an unusable finite normal-matrix inverse, or a nonfinite model-view transform instead of using the screen path's tolerant omission policy. `MetalOffscreenRenderRuntime` additionally validates the requested-aspect model-view-projection products before GPU packing.
- `Engine2/Render Runtime/Viewpoint/*.swift`
  - `RenderViewpoint` carries one output-specific camera, stable `RenderViewpointID`, and monotonic `RenderViewpointRevision` through the Render-owned `PRenderViewpointSource` boundary.
- `Engine2/Render Runtime/Offscreen/*.swift`
  - `POffscreenRenderTarget` accepts an exact immutable `OffscreenRenderRequest` asynchronously and returns an `OffscreenRenderOutcome`; it never implies source sampling or Simulation advancement.
  - Requests require a completed `SimulationPresentationSnapshot`, an explicit `RenderViewpoint`, and `OffscreenRenderSettings`. Successful results carry detached tightly packed top-left BGRA8-sRGB pixels plus the request identity, source cursor, complete viewpoint, and settings.
  - `OffscreenRenderLimits` is caller-selected safety policy. The conservative default may be replaced deliberately by a host prepared for larger allocation, GPU, and readback costs.
- `Engine2/Render Runtime/Artifact/*.swift`
  - `JPEGArtifactEncoder` synchronously derives a detached JPEG from one completed `OffscreenRenderResult` using CPU-side Core Graphics and Image I/O only. It is stateless, `Sendable`, and nonisolated; its caller chooses the execution context.
  - `JPEGQuality` validates the finite closed `0...1` compression-quality domain. `JPEGEncodingSettings` records the selected quality, and `RenderedImageArtifact` preserves the source request identity, Simulation cursor, complete viewpoint, render settings, and encoding settings beside the encoded data.
  - Encoding failure has no Runtime-side effect. A caller may retry with the same detached raw result or choose another JPEG quality without ticking Simulation or issuing another render request.
- `Engine2/Render Runtime/Metal/**/*.swift`
  - `MetalRenderer` is the thin MetalKit screen adapter. It resolves an optional output viewpoint independently from the latest Simulation presentation, selects a frame-ring slot and drawable, owns command-buffer submission/presentation and terminal screen error policy, and delegates reusable encoding.
  - Per-frame state, render passes, backend resources, and Swift/Metal shader contracts live in focused subfolders beneath the Metal backend.
- `Engine2/Render Runtime/Metal/Frame/MetalFrameEncoder.swift`
  - `MetalFrameEncoder` owns authored-material preflight, fixed target formats, frame-buffer packing, pipelines and argument tables, the HDR frame pass, and model draws.
  - Its caller supplies matching scene-color, depth, and destination textures, one `FrameResources` slot, and an already-begun `MTL4CommandBuffer`. The encoder does not sample runtime sources, choose a frame slot, acquire a view or drawable, submit or present, or impose terminal-error policy.
- `Engine2/Render Runtime/Metal/Offscreen/*.swift`
  - `MetalOffscreenRenderRuntime` owns a dedicated `MetalResourceStore` with one frame slot and accepts at most one request at a time. It rejects busy, cancelled-before-submit, over-limit, invalid-viewpoint, malformed-presentation, and over-256-instance requests without submission.
  - Exact model preflight fails rather than silently omitting a missing model or one without complete drawable indexed geometry. Every encoder-visited mesh must have a usable nonempty first vertex-buffer slice and submeshes whose nonempty UInt16/UInt32 index slices remain in bounds. The live screen remains tolerant.
  - Preparation finishes before mutable GPU work. After commit, a retained `MetalOffscreenSubmission` waits for actual queue feedback before releasing the frame slot; cancellation then returns without allocating a readback image, while GPU feedback failure latches the original terminal cause for later requests.
  - `MetalOffscreenRenderTargets` owns request-local shared BGRA8-sRGB destination and private depth textures plus their residency set. Successful readback produces an opaque, tightly packed, top-left `RenderedBGRA8SRGBImage`; the CPU-only JPEG layer consumes that detached value afterward, while PNG, HDR-master/accumulation, persistence, and sinks remain future concerns.
- `Engine2/Render Runtime/Metal/Resource/*.swift`
  - `MetalResourceStore` is the device-scoped owner of the Metal 4 compiler, command queue, typed shader/pipeline/depth/argument-table caches, validated authored material descriptions, decoded models, and frame resources.
  - `MetalResourceStore.defaultFrameCount` and pipeline target formats are backend contracts independent of `MetalRenderer`; target formats come from `MetalFrameEncoder`.
  - `MetalResidencyManager` keeps static asset allocations and per-frame allocations in separate committed residency sets and registers externally owned view/layer sets with the command queue.
  - Residency is not object ownership: the store retains backend objects, while residency sets group only `MTLAllocation` values needed by submitted GPU work.
- `Engine2/Render Runtime/View/*.swift`
  - `MetalSceneView` bridges SwiftUI to MetalKit input and drawing and wires separate presentation, viewpoint, and input-sink capabilities selected by the App.
- `Engine2/UI/ContentView.swift`
  - Root App UI that composes independently owned runtime capabilities and app-level controls.
- `Engine2/UI/Input/InputMetalView.swift`
  - Platform adapter that translates AppKit events into `InputEvent` values and submits them through `PInputEventSink`.
- `Engine2UnitTests/`
  - Fast, deterministic Swift Testing coverage directly exercises individual production types and methods.
  - The unit-test tree mirrors the app/source tree where practical.
  - Render contract, frame, presentation, and CPU-side shader-layout tests mirror their production folders under `Engine2UnitTests/Render Runtime/`.
  - `OfflineCaptureCoordinatorTests` exercises both operation kinds, initial and post-advance snapshot retention, at-most-once advance submission, exact current cursor checking, cross-operation shared-gate refusal, identity/settings/image-size mismatch rejection, typed post-submission cancellation-ID mismatch, cancellation boundaries, and source-appropriate retained snapshot/advance/raw-render outcomes through deterministic typed seams.
  - `AgentSessionCoordinatorTests` exercises exact mapping and at-most-once forwarding for both `AgentCaptureSource` cases, their unified replay/conflict/high-water lane, duplicate-in-progress and unique-request busy outcomes, non-consuming admission and non-reflexive-payload rejection, advance-only step limits, count/encoded-byte/raw-byte/oversize eviction, source-specific cursor derivation, accepted cancellation replay, close-and-drain, and maximum-sequence eviction after its successor becomes unrepresentable.
- `Engine2RenderTests/`
  - Render integration coverage owns shader execution, offscreen GPU submission, renderer/resource assembly, packaged model decoding, and end-to-end presentation validation.
  - `MetalFrameEncoderTests` drives the production encoder with caller-owned offscreen textures and explicit residency, queue feedback, and readback without an `MTKView` or `CAMetalDrawable`.
  - `MetalOffscreenRenderRuntimeTests` drives the production exact request/result boundary through real GPU completion and detached readback without a view or drawable.
  - `OfflineCaptureConfigurationTests` drives sequential production advance captures through real fixed-step Simulation, Metal submission/readback, and Image I/O JPEG derivation using only the assembly's public cursor and capture capability.
  - `AgentSessionConfigurationTests` drives production agent requests through only the closed assembly surface: advance tick zero to tick one, current-capture an alternate view at tick one, replay that byte-identical current response without render or advance work, then advance tick one to tick two.
  - Test-only Metal renderers and GPU submission helpers remain private to this target instead of compiling into the unit-test bundle.
  - Render integration tests mirror the Metal backend folders, with shared test-only infrastructure grouped under `Engine2RenderTests/Render Runtime/Metal/Support/`.
### Folder Organization
New simulation systems are added to `Engine2/Simulation Runtime/Engine/System/<system name>.`
When a new system is created, the requisite components, resources, and protocols will be added in their own subfolders. The `System` folders are organized in funcitonal blocks to ensure proximity of files used in that `System`.
## High-Level Direction
### 1. Keep Protocols
Protocols are staying.
They serve two purposes:
- ergonomic game-level typing (`Ball: PMovable`, `Ball: PSelectable`, etc.)
- a clean bridge to UI and tooling, where code wants typed objects rather than raw component rows
Do not remove the protocol layer unless the project direction changes deliberately.
### 2. Use `Entity` as a Base Class for Live Objects
The project is trending toward `Entity` as a superclass rather than a protocol.
Intent:
- common identity/lifecycle plumbing lives in one place
- concrete game objects are reference types with stable identity
- capability protocols sit on top of that base class
Important:
- systems should not use these objects in hot loops
- these objects are facades/bridges, not the simulation backend
### 3. ECS Is the Simulation Truth
The world's component stores are authoritative.
Entity classes should read from component stores through protocol default implementations. They are not meant to duplicate gameplay state as a second authoritative model.
If future UI code needs current data, prefer:
- live computed accessors backed by component stores
- typed lookup from `EntityID`
- optional object registry or on-demand typed handle reconstruction
### 4. Systems Iterate Stores Directly
This is a key design decision from the conversation:
- systems should iterate `ComponentStore`s directly
- systems should mutate existing component rows with `ComponentStore.update(for:_:)` when changing component fields; reserve `insert` for spawn/registration, adding a missing row, or intentional row replacement/reset
- systems should not read/write motion through entity property wrappers inside hot loops
- object facades are for gameplay ergonomics, scripting-ish code, UI, and selection/inspection flows
If a future system needs `position + velocity`, it should join component stores directly, not loop over `Entity` objects.
### 5. Prefer Simple OOP Creation at the Boundary
Do not over-engineer descriptors/snapshots unless they become necessary.
The favored direction is simple object-oriented creation like:
```swift
let ball = Ball(...)
```
or a closely related `spawn`/factory variant.
The important idea is:
- gameplay code should remain ergonomic
- ECS conversion happens at the world boundary
If spawn-time data needs to be carried through protocols, prefer small, practical values such as `initialPosition`, `initialVelocity`, etc. Avoid introducing multiple nearly identical "spawn/descriptor/snapshot" types unless there is a concrete need.
Current note: `Entity.InitialState` is a practical common seed bag for transform and motion data. Do not let it grow into a dumping ground for specialized gameplay state; prefer concrete entity initializers, world builders, or focused future spawn helpers for data that is not broadly engine-level.
### 6. Motion Model: Use Contribution Accumulation
The project has moved toward a motion contribution model.
Use `CMotion` for translational motion state:
- `velocity`: integrated world-space velocity
- `accelerationIntent`: persistent drive state such as idle or accelerating
- `accumulator.acceleration`: per-tick continuous influences that scale with `dt`
- `accumulator.impulse`: per-tick instantaneous velocity changes that do not scale with `dt`
Design intent:
- gameplay systems emit motion contributions
- persistent drive state is converted into accumulator input before movement
- movement updates velocity, then updates position
Avoid having many systems directly overwrite `CMotion.velocity` unless they are doing explicit override/constraint/collision resolution work.
The runtime-first version of this model is aggregate accumulation, not a per-entity heap of arbitrary contribution objects. If source-level contribution tracking is ever needed for debugging, add that separately.
The angular equivalent is `CAngularMotionAccumulator`:
- `angularAcceleration`: continuous rotational influences that scale with `dt`
- `angularImpulse`: instantaneous angular velocity changes
`SMovement` and `SRotation` currently combine contribution integration and transform advancement. If collision, constraints, or staged scheduling become substantial, consider splitting those phases while preserving the same accumulator semantics.
### Component Updates Should Be In-Place
When a component row already exists, prefer `ComponentStore.update(for:_:)` over constructing a replacement component and passing it back through `insert`.
Use `insert` for:
- spawn-time component creation
- adding a row that may not exist yet
- explicit reset/reseed operations where replacing the full component is the intended behavior
Use `update(for:_:)` for:
- per-tick system mutation
- changing one or two fields on an existing component
- clearing accumulators after integration
- updating transform, motion, or other dense-row state in hot paths
This keeps systems data-oriented and avoids extra sparse lookups, generation checks, and whole-value reconstruction when the dense row can be safely mutated in place.
## Deep-Dive Notes From Current Code
### Spawn Flow Is Capability-Driven
`World.add(_:from:)` is now the boundary where entity protocol conformances turn into component rows. Keep capability defaults centralized there so concrete entities stay ergonomic and do not duplicate ECS row construction.
Calling `add` again for the same live entity currently replaces rows. Treat it as spawn-time registration unless a future explicit reset/reseed operation is introduced.
### Generation Safety Is Partially Implemented
`ComponentStore` lookups use `entity.index` for the sparse lookup but then confirm the full `EntityID`, including generation. That protects reads from stale generations.
However, the store does not yet remove or compact dense rows. If a future free list reuses indices with incremented generations, old dense rows can remain in `entities` and still be visited by direct iteration. Before enabling index reuse, implement component removal/compaction and add tests for stale-generation iteration behavior.
### Facades Are Live Handles
Entity objects hold an `unowned` world reference and computed protocol accessors fatal-error when required backing rows are missing. That is acceptable for strict live game objects, but UI inspection or editor tooling may eventually need optional, non-crashing lookup APIs.
### Engine Loop Boundaries Are Clear
`Engine` owns deterministic fixed-step execution and ordered systems. `SimulationRuntime` owns the authoritative session and exact request boundary. `RealtimeAdvanceDriver` owns wall-clock sampling, remainder, input capture, and pause policy, while `RealtimeAssembly` owns coordinated lifecycle and rebuild cutovers. Keep cadence and peer wiring outside Simulation so the exact core remains easy to test and reuse.
The real-time driver uses a typed per-wake catch-up cap with explicit preserve/discard overflow treatment. `Engine` contains no elapsed-time accumulator or partial-schedule pause mode; every accepted exact step executes the complete schedule.
### Viewpoint Control Is Presentation-Owned
`World.camera` and the camera in `SimulationPresentationSnapshot` provide Simulation's completed default. `ScreenViewpointController` owns the current screen override, and Render resolves that separate value when it projects a frame. Do not put output-specific orbit or zoom back into the default Simulation schedule merely to redraw while paused.

The current `RealtimeAssembly.receive(_:)` fan-out proves one-screen separation only. Do not mistake it for multi-source input routing, route epochs, recipient baselines, observer anchors, or multi-output binding infrastructure.
### Rendering Docs Are Directional
The DocC runtime and render articles contain proposed architecture, not only implemented code. Their important constraints are:
- keep backend-specific Metal state out of `World`
- store only abstract presentation state or handles in ECS
- publish an immutable render snapshot without requiring a Render Runtime to exist
- let the Render Runtime consume completed snapshots according to its own cadence
- let each output resolve an explicit viewpoint independently, with the Simulation-published camera as a valid fallback
- keep reusable frame encoding independent of MetalKit surface acquisition, source sampling, queue submission, presentation, and caller error policy
- keep exact offscreen rendering independent of latest-value source sampling and Simulation advancement; the caller must supply the immutable scene, explicit viewpoint, settings, and coordination policy
- retain every submitted Metal object until real queue feedback; cancellation after commit must not abandon in-flight resources
- keep artifact encoding above raw Render completion: a stateless encoder transforms detached pixels, preserves provenance, selects no execution context, and can be retried without ticking or rerendering
- keep offline capture coordination as the only exposed advance path in its assembly; retain exactly one current completed presentation, update it immediately on completed advance, and make current capture a separate mandatory-cursor operation rather than zero-step advancement or latest-source sampling
- preserve source-appropriate committed advance/current-snapshot and raw-render values in downstream failure outcomes rather than hiding progress, retrying, or rolling back
- validate Simulation completion range/request correlation, exact output dimensions, and every cancellation/result correlation identity before accepting an offline outcome; keep long JPEG CPU work outside the coordinator actor while holding one explicit single-flight gate across advance and current capture
- keep agent-session coordination above the narrow offline capture capability; never expose or inject a second Simulation advance, latest-presentation, or Render path, keep `AgentCaptureSource` inside one idempotency lane, and never let bounded response-cache eviction make an accepted request executable again
### Documentation Can Drift Quickly
The code has already moved past earlier examples such as `Missile` and `CAcceleration`. When editing docs or contributor guidance, check current source names first and update examples to match durable concepts rather than stale placeholder types.
## Guidance for Future Changes
- Do not reintroduce a global static world lookup model.
- Do not introduce process-global mutable resources or runtime service locators to connect runtimes.
- Keep runtime dependencies explicit and wire them at the App boundary.
- Keep output-specific viewpoint state outside authoritative Simulation state; feed it back only through a deliberate Simulation-owned command when gameplay truly requires it.
- Prefer immutable snapshots and events over direct peer-runtime references.
- Do not reintroduce a closed enum registry for component identity.
- Keep component storage per-type.
- Keep systems data-oriented.
- In systems and other mutation-heavy paths, use `ComponentStore.update(for:_:)` for existing rows instead of `insert`-as-replace.
- Keep `World.add(_:from:)` as a capability-to-component boundary unless a clearly better spawn API replaces it.
- Add explicit contribution APIs when needed instead of making many systems or object facades directly overwrite integrated velocity.
- Comment executable logic generously. If a method does real work, prefer a short doc comment plus inline comments at the important steps so control flow and state changes are obvious when reading the code.
- When the user asks for ideas, architecture notes, or future direction to be captured for later, prefer adding or updating DocC content under `Engine2/Engine2.docc/` rather than leaving that intent only in chat or code comments.
- For not-yet-implemented direction, mark the DocC content clearly as proposed or future work, and link new conceptual articles from the DocC landing page when they represent durable engine design.
- Preserve or improve `EntityID.generation` semantics.
- Do not reuse an entity index until component removal and dense iteration behavior are generation-safe.
- Prefer adding capability protocols over deepening inheritance.
- Keep the game-object layer ergonomic, but keep the ECS layer authoritative.
- If adding selection/UI inspection, typed lookup by `EntityID` is a valid direction.
- Mirror direct type and method tests under `Engine2UnitTests/`. For example, tests for `Engine2/Simulation Runtime/Engine/System/Position/System/SMovement.swift` should live in `Engine2UnitTests/Simulation Runtime/Engine/System/Position/System/SMovementTests.swift`.
- Place tests that validate Render across multiple production boundaries under `Engine2RenderTests/`. This includes real shader execution, command submission, GPU lifetime, renderer assembly, and packaged-model decoding.
## Current Gaps / Known TODOs
- Entity destruction, index reuse, and generation incrementing are not implemented.
- `ComponentStore` still needs removal, dense compaction, richer mutation/query helpers, and explicit tests for stale-generation behavior.
- Systems run in one ordered list; the richer DocC scheduling graph/stage model is proposed, not implemented.
- `SMovement` and `SRotation` currently combine integration and transform advancement; the future collision/constraint pipeline may need a more explicit phase split.
- Typed multi-source input routing, route epochs, multi-window/output bindings, Simulation observer anchors, PNG output, artifact persistence/sinks, HDR-master and accumulation policy, atomic multi-view jobs, and a dedicated Render worker remain proposed. The serial offline configuration coordinates exact advance-or-current scene selection, rendering, provenance validation, and JPEG encoding; the agent configuration adds bounded live-process idempotency above both sources. Neither supplies actual MCP transport/authentication/DTOs, durable restart-safe request history, controls, structured observations, artifact persistence, automatic retry, Input, cadence, or a screen. Visual current capture does not fill the structured-observation gap, and physical or semantic control ingress should wait for an actual gameplay consumer.
- Capability accessors are strict live reads with `fatalError`; optional inspection/editor lookup paths do not exist yet.
- Tests do not yet cover component removal, dense iteration with stale generations, or spawn precondition failures.
## Working Assumption for Contributors
When in doubt, choose the simpler design that preserves:
- typed game objects at the API boundary
- component stores as runtime truth
- systems as the place where simulation work happens
That is the core intent this repo is trying to protect.
