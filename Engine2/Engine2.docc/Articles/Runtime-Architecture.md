# Runtime Architecture

This article defines the intended top-level application architecture for Engine2 and the vocabulary used to describe communication between its major parts.

## Status

Partially implemented direction.

The current code implements ``InputRuntime`` as the platform-input lifecycle and latest-snapshot publisher. ``SimulationRuntime`` owns ``Engine`` and ``World`` but no longer owns cadence or a live Input source: its session-qualified ``PSimulationAdvanceTarget`` boundary accepts exact requests and returns correlated completed output. ``ManualConfiguration`` provides a caller-driven assembly, while ``RealtimeConfiguration`` connects Input and Simulation through an App-owned ``RealtimeAdvanceDriver`` with captured transition baselines, typed bounded catch-up, and explicit overflow policy. Async stop-and-drain plus assembly lifecycle generations make coordinated stop and rebuild wait for accepted work without letting stale completion reverse a newer App decision; the cadence task releases the driver between sleeps.

The first output-viewpoint separation is also implemented. ``RealtimeAssembly`` retains an ordinary App-owned ``ScreenViewpointController`` and performs one explicit hard-coded screen-event fan-out to it and ``InputRuntime``. `MetalRenderer` samples the latest ``SimulationPresentationSnapshot`` and independently resolves a ``RenderViewpoint``; ``RenderFrame`` preserves the source Simulation cursor plus optional explicit-viewpoint identity and revision. The screen viewpoint can change while the real-time driver issues no Simulation requests, and the Simulation-published camera remains the exact fallback when there is no override. The default ``Engine`` schedule no longer installs `SInputMapping` or `SCameraInput`, although those legacy types and the legacy ``SimulationLoop`` path remain pending deletion.

Reusable Metal frame encoding and the first production offscreen Runtime boundary are now view-independent. ``MetalFrameEncoder`` owns material preflight, fixed target formats, frame-buffer packing, backend state binding, the HDR pass, and model draws while callers own targets and submission policy. ``MetalRenderer`` is the thin MetalKit screen caller. ``MetalOffscreenRenderRuntime`` implements the backend-neutral async ``POffscreenRenderTarget`` capability using request-carried immutable Simulation presentation, an explicit viewpoint, settings, configurable limits, dedicated one-slot resources, strict presentation/model/geometry preflight, real queue-feedback lifetime, and detached raw BGRA8-sRGB results. It samples no source, advances no Simulation, and owns no view or drawable. ``JPEGArtifactEncoder`` is the implemented stateless CPU transformation from that detached result to a provenance-rich JPEG; it selects no execution context and can be retried without ticking or rerendering. ``OfflineCaptureConfiguration`` now composes those exact capabilities with Simulation behind one serial ``POfflineCaptureTarget``; its coordinator alone may advance that session. Integration coverage drives sequential captures through the public assembly boundary using real fixed-step Simulation, Metal readback, and Image I/O JPEG derivation. Broader authority recovery/arbitration, typed routing, multi-output bindings, observer anchors, PNG and HDR accumulation, artifact persistence/sinks, dedicated Render isolation, and MCP composition remain proposed.

## Runtimes Are the Top-Level Application Objects

A **Runtime** is a long-lived application object that:

- owns mutable state for one major capability
- has a meaningful lifecycle
- processes work over time or in response to external activity
- exposes an explicit boundary instead of sharing its internal state

The App owns, connects, and lifetime-manages its runtimes, starting and stopping those that have an active lifecycle. Likely runtimes include:

- `InputRuntime`
- `SimulationRuntime`
- `RenderRuntime`
- `AudioRuntime`
- `NetworkRuntime`
- `StorageRuntime`
- `AchievementRuntime`

Not every service or helper should become a runtime. A capability earns a runtime boundary when it has meaningful ownership, lifecycle, and ongoing work. A stateless helper or a value used only inside one runtime should remain an ordinary type owned by that runtime.

Runtime names should use a descriptive `Runtime` suffix rather than a single-letter prefix. This leaves `S` unambiguously associated with ECS systems and avoids colliding with the possible `R` prefix for resources.

## Game Content Configures Runtimes

Game-specific entities, initial world construction, presentation descriptions, and packaged assets belong to **Game Content**, not to another runtime. Game Content has no independent cadence or lifecycle. The App uses it to construct and configure runtimes, and each runtime transforms the relevant content into private operational state.

For example, Game Content may provide a world builder to the Simulation Runtime, mesh and material catalogs to the Render Runtime, and sound catalogs plus event-presentation rules to the Audio Runtime. See <doc:Game-Content-Architecture> for the canonical content boundary and proposed construction model.

## Runtime Configurations Assemble Runtimes

A **Runtime Configuration** is an App-owned recipe for selecting runtime implementations, typed connections, advancement policy, lifecycle policy, and per-connection delivery policy for one situation. An App-owned live **Runtime Assembly** strongly retains the instances and connection lifetimes produced from that recipe on the App's behalf.

Concrete ``RealtimeConfiguration``, ``ManualConfiguration``, and ``OfflineCaptureConfiguration`` recipes now construct distinct assemblies. The manual topology owns only caller-driven Simulation with no automatic cadence. The application's real-time topology connects platform input and authoritative Simulation through its App-owned wall-clock driver while one screen independently combines completed snapshots with an App-owned viewpoint. Its assembly is also the current `PInputEventSink`: it forwards each accepted host event to the Input Runtime and the one screen controller. That fixed fan-out is implementation evidence for explicit composition, not the proposed typed routing or multi-window binding model.

The offline topology always contains exactly one Simulation Runtime, one dedicated offscreen Metal Runtime, and one serial coordinator. ``OfflineCaptureAssembly`` exposes only its immutable initial cursor and ``POfflineCaptureTarget``—not either Runtime, a second advance path, Input, wall-clock cadence, a screen, or a generic optional-runtime bag. MCP-driven stepping, headless servers beyond this focused capture topology, replay, and alternate presentation still need their own explicit assemblies without changing what a Simulation tick means.

See <doc:Runtime-Configurations-and-Advancement> for the proposed configuration vocabulary, advance boundary, scenario space, feasibility assessment, and migration path.

## The Simulation Runtime Is Authoritative

The runtimes are peers in ownership and encapsulation, but they are not symmetric in purpose. The **Simulation Runtime** is the authoritative runtime for gameplay state.

The Simulation Runtime owns:

- ``Engine``, the fixed-step definition, and exact step execution
- ``World`` and authoritative ECS state
- ECS components and resources
- scheduled ``PSystem`` implementations
- simulation session and tick identity
- completed Simulation-owned publications

That ownership includes the invariant system schedule. Position, orientation, input consumption, and other mechanics required for a valid simulation remain Simulation Runtime implementation. Future consumer-defined behavior may enter through deliberate extension points, but Game Content does not replace or assemble the simulation's required foundation.

Other runtimes may provide inputs to the Simulation Runtime or project its outputs, but they do not reach into `World` or mutate simulation state directly.

The camera carried by ``SimulationPresentationSnapshot`` is a completed Simulation-authored default. An output may use it exactly or supply a separately owned viewpoint without changing ``World`` or advancing the Simulation cursor. Output-specific free orbit and zoom therefore do not belong in the default Simulation schedule. A future gameplay-authoritative camera rig or sensor may still be ordinary Simulation state processed by complete ticks.

Owning tick execution does not require Simulation to own the policy that decides when a tick is requested. ``SimulationRuntime`` now exposes exact advancement without owning a polling loop, and ``ManualConfiguration`` demonstrates progress with no wall clock. The App-owned ``RealtimeAdvanceDriver`` performs wall-clock polling, elapsed-time accumulation, bounded catch-up/overflow policy, pause/rebase policy, and input capture while Simulation remains the sole executor and publisher of completed ticks. ``SimulationLoop`` and ``Engine/update(deltaTime:inputSnapshot:)`` remain only as legacy migration paths pending final removal.

This makes the Simulation Runtime first among peers: it is the semantic center of the game without becoming a global owner of the other runtimes. The Simulation Runtime must remain valid when Render, Audio, Achievement, Storage, or Network runtimes are absent. Outputs for absent consumers simply go unobserved.

## Runtime Independence Does Not Require Equal Usefulness

A runtime is independent when it can be constructed, lifecycle-managed as appropriate, and tested without hidden access to another runtime's mutable internals. Independence does not mean every runtime is equally useful in isolation.

- An Input Runtime can collect platform input with no active game consuming it.
- A Simulation Runtime can advance with neutral input and no presentation runtimes attached.
- A screen Render Runtime with no simulation snapshot may draw an empty or loading presentation; an exact offscreen request is instead incomplete without its required immutable snapshot and explicit viewpoint.
- An Audio Runtime with no game state may remain silent.
- An Achievement Runtime may wait for relevant game output.

The important constraint is lifecycle safety and explicit inputs, not artificial symmetry.

## Runtime Boundaries Carry Immutable Values

A **Runtime boundary** is the point where ownership changes and one runtime's mutable implementation state stops being visible. Values crossing that boundary should normally be strongly typed and immutable.

Two boundary-value semantics are currently canonical. See <doc:Runtime-Communication> for the proposed publication, ownership, projection, and delivery model.

### Snapshots

A **Snapshot** is immutable state describing one point in time.

Snapshots are:

- replaceable by a newer snapshot
- safe to ignore when no consumer exists
- sufficient for a late consumer to converge on current state
- published without naming a required receiving runtime
- owned as vocabulary by the runtime whose state they describe

Examples include:

- `InputSnapshot`
- `SimulationPresentationSnapshot`
- `AchievementSnapshot`

Snapshot types should use a descriptive `Snapshot` suffix rather than an `S` prefix. The `S` prefix remains reserved for ECS systems.

A receiving runtime may derive its own private snapshot or operational model from a publisher-owned snapshot. For example, the Simulation Runtime publishes `SimulationPresentationSnapshot`; the Render Runtime projects that value into its own render-oriented snapshot. Simulation owns the source vocabulary, Render owns the projection and destination model, and the App owns the connection.

The implemented boundary now separates those roles: ``SimulationPresentationSnapshot`` is publisher-owned abstract presentation state labeled with its exact ``SimulationCursor``, while ``RenderFrame`` is the Render Runtime's private projection. A frame preserves optional source-cursor attribution and, when projected with an explicit ``RenderViewpoint``, its ``RenderViewpointID`` and ``RenderViewpointRevision``. The App connects the read-only presentation and viewpoint sources explicitly. This is one deliberate Simulation Runtime publication plus an output-owned selection, not a universal snapshot of every simulation concern.

Exact offscreen work uses a directed request/result boundary instead of sampling those latest sources. ``OffscreenRenderRequest`` carries one completed snapshot, one explicit viewpoint, and settings by value through ``POffscreenRenderTarget``. A successful ``OffscreenRenderResult`` echoes the request identity, source cursor, complete viewpoint, settings, and detached image, so slow rendering cannot silently switch to a newer scene or camera.

Artifact derivation begins only after that exact result exists. ``JPEGArtifactEncoder`` synchronously transforms its detached BGRA8-sRGB pixels on the CPU and returns ``RenderedImageArtifact`` with the source request identity, Simulation cursor, complete viewpoint, render settings, and JPEG settings intact. The encoder is an ordinary stateless value rather than a Runtime; the caller chooses where it executes. Encoding failure leaves the raw result available for retry and never implies another Simulation advance or render.

### Events

An **Event** is an immutable fact published by a runtime after something happened within that runtime's authority.

For example, the Simulation Runtime might publish facts such as:

- a weapon fired
- a collision occurred
- an entity was destroyed
- a level completed

Audio, Achievement, Network, or tooling runtimes may observe those events when present. The Simulation Runtime does not require any particular reaction and remains correct when no consumer exists.

Like snapshots, event schemas belong to their publisher's authority. A consumer may transform an event into private behavior or state, but it does not redefine the fact that the publisher reported.

Events and snapshots complement one another:

- a snapshot answers "what is true now?"
- an event answers "what just happened?"

A runtime that starts late can converge from the latest snapshot. Ephemeral events that occurred while it was absent may be intentionally missed. If historical delivery becomes necessary, that requires an explicit durable record or journal rather than silently changing ordinary event semantics.

Snapshots and events form independent logical publication lanes. Snapshots use replaceable latest-value semantics; events use ordered-stream semantics within one publisher's authority. Input and simulation presentation currently implement latest-snapshot sources. General event publication, buffering, subscription, and correlation mechanisms remain proposed work.

The current `InputEvent` name denotes a value accepted from a platform adapter through `PInputEventSink`. It is ingress to ``InputRuntime``, not an Input Runtime-published ordered event lane. A future discrete-transition publication may use events, but it needs an explicit ordering, retention, and consumer-position policy rather than reusing host callbacks as if they were already a runtime event stream.

## Prefer Choreography Between Peer Runtimes

Peer runtimes should usually communicate through choreography:

1. A runtime publishes a snapshot or event within its own authority.
2. The App connects that output to any interested runtime inputs.
3. The publishing runtime does not know which consumers exist.

For example:

```text
InputMetalView     -- InputEvent -----------------------------> RealtimeAssembly
RealtimeAssembly  -- hard-coded device-state fan-out --------> InputRuntime
RealtimeAssembly  -- hard-coded screen-gesture fan-out ------> ScreenViewpointController
InputRuntime       -- latest InputSnapshot -------------------> RealtimeAdvanceDriver
RealtimeAdvanceDriver -- SimulationAdvanceRequest -----------> SimulationRuntime
SimulationRuntime -- SimulationPresentationSnapshot ---------+--> RenderRuntime
ScreenViewpointController -- RenderViewpoint -----------------+
SimulationRuntime -- selected SimulationEvent ----------------> AudioRuntime
SimulationRuntime -- selected SimulationEvent ----------------> AchievementRuntime
```

The arrows show App-owned, explicitly typed wiring, not direct ownership between the runtimes. ``ScreenViewpointController`` is a connection/controller retained by the assembly, not another Runtime. The two current event arrows out of ``RealtimeAssembly`` are deliberately hard-coded for one interactive screen and do not yet provide source identity, route epochs, recipient baselines, exclusivity, or multi-window binding. The real-time Simulation path combines a latest-value publication with a deliberate directed advance request; the Simulation publication paths remain choreography. Rendering consumes the simulation presentation snapshot and independently resolved viewpoint to derive a private render model; it does not require a simulation event lane. Future continuous audio, networking, tooling, or other needs may justify additional purpose-specific publisher-owned snapshots rather than expanding one universal simulation snapshot.

Engine2 should not connect these publications through a process-global event bus, process-global snapshot database, or runtime service locator. A reusable App-owned router or exchange may eventually implement the connections, but it must preserve the explicit typed topology and may not make arbitrary publishers globally discoverable.

Avoid making directed commands the default peer-to-peer boundary. "AudioRuntime, play this sound" couples the Simulation Runtime to an audio capability. "A weapon fired" states a fact within the Simulation Runtime's authority and allows an optional Audio Runtime to decide how that fact should sound.

Directed request-and-result workflows are still valid when a dependency is intentional, but the App should normally coordinate them. For example, the App can ask a Storage Runtime to load a saved `GameCheckpoint`, then construct or replace the Simulation Runtime with the result. The Simulation Runtime does not need to own or discover the Storage Runtime.

``POffscreenRenderTarget`` is another directed capability. Its concrete Metal Runtime neither discovers nor calls Simulation; an App-owned coordinator passes the exact completed snapshot and explicit viewpoint into the request and decides whether render completion gates another Simulation advance.

JPEG derivation is not another directed Runtime capability. It is a local transformation of an already completed value. ``OfflineCaptureCoordinator`` now submits one supplied exact advance request at most once, renders only the returned immutable snapshot, validates that the completed render echoed every identity-bearing input, and encodes JPEG. The request may contain one or more fixed steps; the coordinator never retries or rolls back automatically. A future MCP coordinator may reuse these narrow capabilities, but no MCP transport/idempotency layer, persistence boundary, or `ArtifactSink` is implemented yet.

## Runtimes Advance at Different Cadences

There is no single universal application frame.

- Input arrives according to platform event delivery.
- The Simulation Runtime executes fixed simulation ticks when the active advance authority requests progress.
- The current screen viewpoint changes when its configured presentation gestures arrive, including while the Simulation cursor is frozen.
- A screen Render Runtime submits work according to presentation cadence; ``MetalOffscreenRenderRuntime`` submits only when an exact asynchronous request is accepted.
- ``JPEGArtifactEncoder`` has no cadence or isolation policy; its caller selects an execution context for each synchronous CPU transformation.
- ``OfflineCaptureCoordinator`` has no automatic cadence; one accepted request owns the complete advance-render-encode sequence, while overlapping actor-reentrant requests receive immediate busy refusal.
- Audio, Network, and Storage runtimes may be event-driven or use their own scheduling policies.

One host update may therefore collect input, execute zero or several simulation ticks, publish one new simulation presentation snapshot, and present zero or several render frames. Runtime boundaries must not assume one-to-one cadence.

The word **tick** refers specifically to one fixed Simulation Runtime simulation advancement. A ``SimulationCursor`` pairs that resettable value with the current session identity. A render frame refers to one presentation attempt. An input snapshot is a revisioned latest value defined by the Input Runtime. ``RealtimeAdvanceDriver`` captures one immutable input assignment with each exact request; Simulation applies it only when that request begins its fixed-step work. The legacy ``SimulationLoop`` remains temporarily but is no longer the application's configured advance path.

Other configurations may request exact ticks after an offline render completes, when an MCP caller is ready, after a network input barrier, or as fast as a deterministic test permits. Wall time, render time, network time, output-media time, and simulation time remain distinct. The configuration assigns advance authority; Simulation retains tick meaning and mutation authority.

## ECS Systems Live Inside the Simulation Runtime

An ECS **System** is not a runtime. It is scheduled simulation logic owned by the Simulation Runtime and operating on ``World``.

This distinction keeps the `S` prefix precise:

- `SInputMapping` and `SCameraInput` remain ECS-system types while they await deletion, even though the default ``Engine`` schedule no longer installs them.
- `SRenderExtraction` may eventually be an ECS presentation-export system, but actual rendering belongs to the Render Runtime.
- `InputRuntime` and `RenderRuntime` are top-level owners with independent lifecycles, not ECS systems.

## Resources Stay Within an Ownership Scope

A **Resource** is long-lived mutable state scoped to a runtime or, for simulation resources, to a world. Sharing is not what makes a value a resource; ownership, lifetime, and non-entity cardinality do.

- Input state accumulated by the Input Runtime can be an Input Runtime resource.
- Camera or simulation configuration can be a Simulation Runtime or World resource.
- Metal pipeline caches and GPU allocations are Render Runtime state.
- An octree used only by one collision system is private system state, not automatically a resource.
- A long-lived collision-work resource may hold per-tick candidate data written by one system and read by another.

Do not use process-global mutable resources to connect runtimes. Globals hide ownership, prevent multiple runtime instances, contaminate tests, and make lifecycle and concurrency behavior implicit. The App should wire explicit runtime boundaries instead.

## Current-to-Proposed Mapping

The current implementation maps onto the proposed model as follows:

| Current type | Emerging responsibility |
| --- | --- |
| ``InputRuntime`` | Implemented App-owned Input Runtime lifecycle, platform-event ingress, and latest immutable input-snapshot publication |
| `InputMetalView` | Platform adapter that submits `InputEvent` values through the current assembly's `PInputEventSink`; it does not call Simulation directly |
| `InputSnapshot`, `InputRevision`, and `PInputSnapshotSource` | Implemented revisioned latest-value boundary containing held state plus cumulative pointer-motion and scroll totals |
| `InputState` and default Simulation input systems | Simulation-owned fixed-tick input state, history, and transient cleanup after snapshot ingestion; legacy camera mapping/control types are no longer installed by default |
| ``SimulationSessionID`` and ``SimulationCursor`` | Implemented identity for one authoritative timeline and one committed position within it |
| ``SimulationRuntime`` and ``PSimulationAdvanceTarget`` | Implemented authoritative state, exact request serialization, expected-cursor validation, immutable input assignment, and correlated completed publication without owning cadence |
| ``ManualConfiguration`` and ``ManualAssembly`` | Implemented caller-driven topology with no Input Runtime or automatic cadence |
| ``RealtimeConfiguration``, ``RealtimeAssembly``, and ``RealtimeAdvanceDriver`` | Implemented real-time composition with App-owned cadence, pause policy, exact requests, coordinated lifecycle, and one hard-coded screen-event fan-out; broader authority recovery and typed routing remain |
| ``ScreenViewpointController`` | Implemented ordinary App-owned controller for one screen's optional free-orbit override; it passes through the exact latest Simulation camera until meaningfully changed and can revise while Simulation is paused |
| ``SimulationLoop`` | Legacy host-time polling and input-sampling path retained while real-time migration is completed |
| ``Engine`` | Fixed-step scheduler inside the Simulation Runtime; exact steps run the complete schedule, while the legacy elapsed-time and gated-pause path remains transitional |
| ``World`` | Authoritative simulation state inside the Simulation Runtime |
| ``SimulationPresentationSnapshot`` | Latest completed publisher-owned Simulation Runtime presentation value labeled with its exact cursor; its camera is the default for outputs without an override |
| ``RenderViewpoint``, ``RenderViewpointID``, ``RenderViewpointRevision``, and `PRenderViewpointSource` | Implemented immutable output-specific camera selection and Render-owned source boundary |
| ``RenderFrame`` | Render Runtime-owned private projection derived from one Simulation snapshot and an optional explicit viewpoint, preserving both kinds of attribution; screen projection tolerantly omits malformed entities while exact projection returns a typed error |
| ``MetalFrameEncoder`` | Implemented view-independent preparation and encoding against caller-owned textures, `FrameResources`, and an already-begun Metal 4 command buffer; it owns no source sampling, surface, queue submission, presentation, or error policy |
| `MetalSceneView` and `MetalRenderer` | Current MetalKit screen adapter; samples presentation/viewpoint sources, selects ring slots and drawables, submits, presents, and owns screen error policy while delegating reusable encoding |
| ``POffscreenRenderTarget`` and its request/outcome values | Implemented backend-neutral exact asynchronous boundary requiring an immutable Simulation presentation, explicit viewpoint, and render settings; successful results preserve request, source, viewpoint, and settings provenance |
| ``MetalOffscreenRenderRuntime`` | Implemented production Metal offscreen Runtime with configurable limits, one dedicated frame slot, single-flight refusal, strict presentation/model/drawable-geometry preflight, queue-feedback lifetime, defined cancellation, terminal GPU-failure latching, and detached BGRA8-sRGB readback; owns no source, Simulation advance, view, drawable, or artifact encoder |
| ``JPEGArtifactEncoder`` and ``RenderedImageArtifact`` | Implemented stateless CPU JPEG derivation from detached exact offscreen results with validated quality and preserved request, cursor, viewpoint, render, and encoding provenance; owns no Runtime lifecycle, execution context, Metal work, persistence, or sink |
| ``OfflineCaptureConfiguration``, ``OfflineCaptureAssembly``, and ``OfflineCaptureCoordinator`` | Implemented closed serial topology exposing only initial cursor plus ``POfflineCaptureTarget``; the sole effective advance authority submits each supplied advance request at most once, renders the returned snapshot, validates provenance, and encodes JPEG with immediate busy backpressure and progress-preserving outcomes |
| ``MetalResourceStore`` | Device-scoped backend owner whose default frame count and compiled target formats are independent of the screen adapter |

Future changes should introduce the remaining boundaries incrementally. The one-screen fan-out is not a substitute for typed multi-source routing, route epochs, observer anchors, or multi-output bindings, and the focused serial offline assembly is not a high-quality accumulation pipeline, artifact sink, persistence layer, dedicated Render worker, or MCP assembly. PNG and HDR accumulation are not implemented. Ordered discrete input-transition publication and retained input replay are also not part of the implemented latest-snapshot boundary. Add those capabilities only with explicit delivery and storage semantics.

## Related Direction

- <doc:Runtime-Communication>
- <doc:Runtime-Configurations-and-Advancement>
- <doc:Game-Content-Architecture>
- <doc:Engine-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
- <doc:Rendering-Architecture>
- <doc:System-Scheduling>
