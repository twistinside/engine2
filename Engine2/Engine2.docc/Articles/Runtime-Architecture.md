# Runtime Architecture

This article defines the intended top-level application architecture for Engine2 and the vocabulary used to describe communication between its major parts.

## Status

Partially implemented direction.

The current code implements ``InputRuntime`` as the platform-input lifecycle, physical-to-semantic mapper, and latest-snapshot publisher. Its injected `InputMappingConfiguration` maps physical bindings to context-free translation, interaction, fire, camera, and selection intent without reading gameplay state. ``SimulationRuntime`` owns ``Engine`` and ``World`` but no wall-clock cadence or live Input source. Its session-qualified ``SimulationAdvanceTarget`` boundary accepts exact requests and returns correlated completed output.

Every concrete assembly conforms to ``RuntimeAssembly``, constructs its topology from injected Game Content, and implements `body: some View` as that topology's SwiftUI root. The current ``RealtimeAssembly`` connects Input and Simulation through an assembly-owned ``RealtimeAdvanceDriver`` with typed bounded catch-up and explicit overflow policy.

The screen boundary remains narrow. `MetalSceneView` hosts one `MetalScenePlatformView`: the same `MTKView` supplies drawables to `MetalRenderer` and forwards physical AppKit events to ``InputRuntime`` through `InputEventSink`. ``InputRuntime`` publishes cumulative semantic camera totals, and ``CameraInputSystem`` applies their interval deltas to `World.camera` only within complete Simulation ticks. `MetalRenderer` samples the latest ``SimulationPresentationSnapshot`` and uses that publication's camera exactly. ``MetalFrameEncoder`` owns reusable frame preparation and encoding while ``MetalRenderer`` owns screen-target acquisition, submission, presentation, and error policy.

The current screen graph has no standalone `RenderRuntime` lifecycle type. References to the Render Runtime below describe the intended top-level owner of responsibilities currently split across the assembly, view coordinator, renderer, and resource store.

The mining slice adds a separate SwiftUI selected-entity inspector through a narrow, read-only Simulation-owned source. Its focused orbit-assist callback passes the displayed entity's full ``EntityID`` through ``RealtimeAssemblyViewModel`` to ``RealtimeAdvanceDriver`` without exposing `World` or backend Render state.

Offscreen rendering, snapshot export, replay, and agent control are outside the current release. Broader authority recovery, typed multi-source routing, multi-output bindings, observer anchors, and other Runtime topologies remain proposed.

## Runtimes Are the Top-Level Application Objects

A **Runtime** is a long-lived application object that:

- owns mutable state for one major capability
- has a meaningful lifecycle
- processes work over time or in response to external activity
- exposes an explicit boundary instead of sharing its internal state

The App selects and retains one Runtime Assembly. That assembly constructs, connects, and lifetime-manages its runtimes. It is the topology's root view and owns any topology-specific reversible presentation work in its body. Likely runtimes include:

- `InputRuntime`
- `SimulationRuntime`
- `RenderRuntime`
- `AudioRuntime`
- `NetworkRuntime`
- `StorageRuntime`
- `AchievementRuntime`

Not every service or helper should become a runtime. A capability earns a runtime boundary when it has meaningful ownership, lifecycle, and ongoing work. A stateless helper or a value used only inside one runtime should remain an ordinary type owned by that runtime.

Runtime names use a descriptive `Runtime` suffix. Concrete components and systems use descriptive `Component` and `System` suffixes, while protocols use their domain role without a marker prefix.

## Game Content Configures Runtimes

Game-specific entities, physical input mappings, controlled Simulation behavior, initial world construction, presentation descriptions, and packaged assets belong to **Game Content**, not to another runtime. Game Content has no independent cadence or lifecycle. The App constructs selected Game Content and passes it through ``RuntimeAssembly/init(using:)``. The assembly supplies each relevant portion to its runtimes. Concrete assemblies may expose direct initializers for focused policy required by their topology. Each runtime transforms the relevant content into private operational state.

For example, ``BasicGameContent`` supplies its world builder, Input mapping, standard Simulation behavior, named ``SimulationConfiguration/basicGame`` policy, and backend-neutral Render asset catalog. ``MiningGameContent`` supplies the corresponding mining slice and is selected by the current App. Future Game Content may also provide sound catalogs and event-presentation rules to an Audio Runtime. See <doc:Game-Content-Architecture> for the canonical content boundary and proposed construction model.

## Runtime Assemblies Construct and Present Runtimes

A **Runtime Assembly** is the App-owned composition object that selects runtime implementations and focused policy, constructs and strongly retains the runtime graph, owns connection and lifecycle ordering, and acts as the topology's root UI.

``RuntimeAssembly`` refines `View` and adds Game Content construction. Each concrete assembly implements `body: some View`, so the assembly itself is the SwiftUI root and may apply SwiftUI appearance modifiers for its own reversible presentation work. The protocol deliberately does not contain common visibility operations, optional Runtime capabilities, or topology-specific terminal shutdown. `Engine2App` constructs selected content, retains its compile-time assembly selection as opaque `some RuntimeAssembly`, and renders that value directly.

Concrete assemblies are value types because SwiftUI requires custom views to use value semantics. Their stored Runtime, driver, and focused state references preserve one live topology across SwiftUI copies. Copying an assembly value does not reconstruct the graph; calling an initializer does. ``RealtimeAssemblyLifecycleState`` shares lifecycle transition identity across copies.

Concrete assemblies accept Game Content through the common initializer and may accept focused topology-specific policy through direct initializers. The application's real-time topology connects platform input and authoritative Simulation through its assembly-owned wall-clock driver. `MetalSceneView` gives its single `MetalScenePlatformView` the assembly's ``InputRuntime`` through the narrow `InputEventSink` capability, while `MetalRenderer` receives only completed ``SimulationPresentationSnapshot`` values and uses each selected snapshot's camera exactly. ``RealtimeAssembly`` owns lifecycle and advancement coordination rather than event fan-out or screen-camera state. This direct one-source wiring is implementation evidence for explicit composition, not the proposed typed routing or multi-window binding model.

See <doc:Runtime-Assemblies-and-Advancement> for the assembly vocabulary, implemented advance boundary, current real-time topology, and constraints on future topologies.

## The Simulation Runtime Is Authoritative

The runtimes are peers in ownership and encapsulation, but they are not symmetric in purpose. The **Simulation Runtime** is the authoritative runtime for gameplay state.

The Simulation Runtime owns:

- ``Engine``, the fixed-step definition, and exact step execution
- ``World`` and authoritative ECS state
- ECS components and resources
- scheduled ``System`` implementations
- simulation session and tick identity
- completed Simulation-owned publications

That ownership includes the invariant system schedule. Position, orientation, semantic input consumption, and other mechanics required for a valid simulation remain Simulation Runtime implementation. Game Content can supply systems through ``SimulationBehavior`` and the fixed stages of ``SimulationSystemSchedule``, but it cannot replace or reorder the simulation's required foundation.

Other runtimes may provide inputs to the Simulation Runtime or project its outputs, but they do not reach into `World` or mutate simulation state directly.

The camera carried by ``SimulationPresentationSnapshot`` is the completed Simulation-authored camera used exactly by the real-time screen. The live screen has no separate viewpoint authority. ``InputRuntime`` maps pointer and scroll input into cumulative semantic totals; Simulation derives their interval deltas and ``CameraInputSystem`` mutates `World.camera` only during a complete tick. Future gameplay-authoritative rigs or sensors belong at that same Simulation boundary.

Owning tick execution does not require Simulation to own the policy that decides when a tick is requested. ``SimulationRuntime`` exposes exact advancement without owning a polling loop, and focused tests exercise that boundary without a wall clock. The assembly-owned ``RealtimeAdvanceDriver`` performs wall-clock polling, elapsed-time accumulation, bounded catch-up/overflow policy, pause/rebase policy, and input capture while Simulation remains the sole executor and publisher of completed ticks. The production assembly uses ``SimulationRuntime/fixedTimeStep`` and cannot redefine what one tick means.

This makes the Simulation Runtime first among peers: it is the semantic center of the game without becoming a global owner of the other runtimes. The Simulation Runtime must remain valid when Render, Audio, Achievement, Storage, or Network runtimes are absent. Outputs for absent consumers simply go unobserved.

## The Mining Slice Composes Two Motion Policies

The mining slice keeps all gameplay state in the Simulation Runtime while using two deliberate motion policies:

- The star is the gravity source, and the player skiff dynamically integrates gravity, thrust, fuel use, changing cargo mass, and collision response.
- Asteroids and the depot follow deterministic analytic circular rails. Their rail systems prepare authoritative position and velocity before force contribution and movement work.

Rails keep quiet bodies reproducible and inexpensive; they are not approximate output from the skiff's dynamic integrator. A future perturbation feature must define an explicit rail-to-dynamics transition instead of applying forces to a body while a rail system continues overwriting its state.

Selection remains authoritative ECS state. ``InputRuntime`` publishes only context-free translation, interaction, fire, camera, and selection intent. Simulation resolves the selected entity and routes held controls only when that entity advertises player-control capability. Selecting a non-controllable entity therefore leaves the skiff coasting without requiring Input to know which entity exists.

Orbit circularization starts with a separate one-shot command, not another context-free Input Runtime field. The real-time driver stages it behind a generation tag and carries it on the next cursor-qualified ``SimulationAdvanceRequest``. ``SimulationRuntime`` imports it only for that request's first tick, where ``OrbitCircularizationSystem`` consumes it during Mining Game Content's `inputConsumption` stage and may engage per-entity Simulation-owned autopilot state. During that tick and while the state remains engaged on later ticks, ``OrbitCircularizationAutopilotSystem`` runs after gravity and before manual flight control, suppresses manual translation for the engaged entity, and burns under finite thrust, current fuel, live mass, and normal integration. Its live ``OrbitCircularizable`` estimate exposes delta-velocity reserve and minimum burn duration to the protocol-backed inspector without adding gameplay state to ``SimulationPresentationSnapshot``.

The mining camera uses the orbital plane's Z normal as its configured orbit axis and starts from a more top-down initial offset. Orbiting therefore keeps a usable view of the XY plane instead of turning it edge-on. Flight control normalizes the camera's projected right and up directions before mapping translation, so screen-relative steering remains stable around the orbit.

## Runtime Independence Does Not Require Equal Usefulness

A runtime is independent when it can be constructed, lifecycle-managed as appropriate, and tested without hidden access to another runtime's mutable internals. Independence does not mean every runtime is equally useful in isolation.

- An Input Runtime can collect platform input with no active game consuming it.
- A Simulation Runtime can advance with neutral input and no presentation runtimes attached.
- A screen Render Runtime with no simulation snapshot may draw an empty or loading presentation.
- An Audio Runtime with no game state may remain silent.
- An Achievement Runtime may wait for relevant game output.

The important constraint is lifecycle safety and explicit inputs, not artificial symmetry.

## Runtime Boundaries Carry Immutable Values

A **Runtime boundary** is the point where ownership changes and one runtime's mutable implementation state stops being visible. Values crossing that boundary should normally be strongly typed and immutable.

The architecture distinguishes two boundary-value semantics. Latest-value snapshots are implemented for Input and Simulation presentation; ordered event publication remains proposed. See <doc:Runtime-Communication> for the publication, ownership, projection, and delivery model.

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

Snapshot types use a descriptive `Snapshot` suffix.

A receiving runtime may derive its own private snapshot or operational model from a publisher-owned snapshot. For example, the Simulation Runtime publishes `SimulationPresentationSnapshot`; the Render layer projects that value into its own render-oriented snapshot. Simulation owns the source vocabulary, Render owns the projection and destination model, and the Runtime Assembly owns the connection on the App's behalf.

The implemented boundary separates those roles: ``SimulationPresentationSnapshot`` is publisher-owned abstract presentation state labeled with its exact ``SimulationCursor``, while ``RenderFrame`` is the current Render layer's private projection. `RenderFrame(projecting:)` preserves the source cursor and uses the snapshot camera exactly. ``RealtimeAssembly`` connects the live screen to Simulation only through the read-only presentation source. This is one deliberate Simulation Runtime publication, not a universal snapshot of every simulation concern.

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

The current `InputEvent` name denotes a value accepted from a platform adapter through `InputEventSink`. It is ingress to ``InputRuntime``, not an Input Runtime-published ordered event lane. A future discrete-transition publication may use events, but it needs an explicit ordering, retention, and consumer-position policy rather than reusing host callbacks as if they were already a runtime event stream.

## Prefer Choreography Between Peer Runtimes

Peer runtimes should usually communicate through choreography:

1. A runtime publishes a snapshot or event within its own authority.
2. The selected Runtime Assembly connects that output to any interested runtime inputs.
3. The publishing runtime does not know which consumers exist.

For example:

```text
MetalScenePlatformView -- InputEvent -------------------------> InputRuntime
InputRuntime       -- latest InputSnapshot -------------------> RealtimeAdvanceDriver
RealtimeAdvanceDriver -- SimulationAdvanceRequest -----------> SimulationRuntime
SimulationRuntime -- SimulationPresentationSnapshot ----------> screen Render path
SimulationRuntime -- selected-entity source ------------------> SwiftUI inspector
Orbit-assist button -- EntityID callback ---------------------> RealtimeAssembly
RealtimeAssembly -- staged orbit command ---------------------> RealtimeAdvanceDriver
SimulationRuntime -- future selected SimulationEvent ---------> AudioRuntime
SimulationRuntime -- future selected SimulationEvent ---------> AchievementRuntime
```

The arrows show assembly-owned, explicitly typed wiring, not direct ownership between the runtimes. The current `MetalScenePlatformView` connection is deliberately direct and does not yet provide source identity, route epochs, recipient baselines, exclusivity, or multi-source policy. The real-time Simulation path combines a latest-value semantic-input publication with a deliberate directed advance request; the optional orbit command is captured into that same request rather than creating a second advance authority. The Simulation publication paths remain choreography. Screen rendering consumes the Simulation presentation and its camera as one completed value. The selected-entity inspector uses its separate narrow source, not the render snapshot, and its callback cannot mutate the facade. Future continuous audio, networking, tooling, or other needs may justify additional purpose-specific publisher-owned snapshots rather than expanding one universal simulation snapshot.

Engine2 should not connect these publications through a process-global event bus, process-global snapshot database, or runtime service locator. A reusable assembly-owned router or exchange may eventually implement the connections, but it must preserve the explicit typed topology and may not make arbitrary publishers globally discoverable.

Avoid making directed commands the default peer-to-peer boundary. "AudioRuntime, play this sound" couples the Simulation Runtime to an audio capability. "A weapon fired" states a fact within the Simulation Runtime's authority and allows an optional Audio Runtime to decide how that fact should sound.

Directed request-and-result workflows are still valid when a dependency is intentional, but an App-owned assembly or its focused coordinator should normally coordinate them. For example, an assembly can ask a Storage Runtime to load a saved `GameCheckpoint`, then construct or replace the Simulation Runtime with the result. The Simulation Runtime does not need to own or discover the Storage Runtime.

## Runtimes Advance at Different Cadences

There is no single universal application frame.

- Input arrives according to platform event delivery.
- The Simulation Runtime executes fixed simulation ticks when the active advance authority requests progress.
- The screen Render path submits work according to presentation cadence and may redraw one completed snapshot repeatedly, but its camera changes only when it selects a different completed Simulation publication.
- Audio, Network, and Storage runtimes may be event-driven or use their own scheduling policies.

One host update may therefore collect input, execute zero or several simulation ticks, publish one new simulation presentation snapshot, and present zero or several render frames. Runtime boundaries must not assume one-to-one cadence.

The word **tick** refers specifically to one fixed Simulation Runtime simulation advancement. A ``SimulationCursor`` pairs that resettable value with the current session identity. A render frame refers to one presentation attempt. An input snapshot is a revisioned latest value defined by the Input Runtime. ``RealtimeAdvanceDriver`` captures one immutable input assignment with each exact request; Simulation applies it only when that request begins its fixed-step work.

Other assemblies may request exact ticks after a network input barrier or as fast as a deterministic test permits. Wall time, render time, network time, and simulation time remain distinct. The assembly assigns advance authority; Simulation retains tick meaning and mutation authority.

## ECS Systems Live Inside the Simulation Runtime

An ECS **System** is not a runtime. It is scheduled simulation logic owned by the Simulation Runtime and operating on ``World``.

Concrete system names make this distinction explicit:

- `CameraInputSystem`, gameplay control systems, and `MovementSystem` are scheduled Simulation logic. Physical-to-semantic mapping remains Input Runtime behavior, while Simulation interprets semantic intent.
- `RenderExtractionSystem` may eventually be an ECS presentation-export system, but actual rendering belongs to the Render Runtime.
- `InputRuntime` is a top-level owner with an independent lifecycle, not an ECS system. A future `RenderRuntime` would preserve that distinction for Render.

## Resources Stay Within an Ownership Scope

A **Resource** is long-lived mutable state scoped to a runtime or, for simulation resources, to a world. Sharing is not what makes a value a resource; ownership, lifetime, and non-entity cardinality do.

- Input state accumulated by the Input Runtime can be an Input Runtime resource.
- Camera or simulation configuration can be a Simulation Runtime or World resource.
- Metal pipeline caches and GPU allocations are state owned by the current Render layer and, eventually, a Render Runtime.
- An octree used only by one collision system is private system state, not automatically a resource.
- A long-lived collision-work resource may hold per-tick candidate data written by one system and read by another.

Do not use process-global mutable resources to connect runtimes. Globals hide ownership, prevent multiple runtime instances, contaminate tests, and make lifecycle and concurrency behavior implicit. The App-owned assembly should wire explicit runtime boundaries instead.

## Current-to-Proposed Mapping

The current implementation maps onto the proposed model as follows:

| Current type | Implemented role |
| --- | --- |
| ``InputRuntime`` | Implemented assembly-retained Input Runtime lifecycle, platform-event ingress, context-free physical-to-semantic mapping, and latest immutable input-snapshot publication |
| `MetalScenePlatformView` | The single onscreen `MTKView`: supplies the drawable surface to `MetalRenderer` and submits physical `InputEvent` values to ``InputRuntime`` through `InputEventSink`; contains neither rendering nor semantic mapping logic |
| `InputSnapshot`, `InputRevision`, and `InputSnapshotSource` | Implemented revisioned latest-value boundary containing held translation and interaction intent plus cumulative camera-orbit, camera-zoom, selection-press, and fire-press values |
| ``InputState`` and default Simulation input systems | Simulation-owned authoritative fixed-tick semantic input, interval-delta derivation, ECS selection/control interpretation, camera application, and transient cleanup |
| ``SimulationSessionID`` and ``SimulationCursor`` | Implemented identity for one authoritative timeline and one committed position within it |
| ``SimulationRuntime`` and ``SimulationAdvanceTarget`` | Implemented authoritative state, exact request serialization, expected-cursor validation, immutable first-step input and optional orbit-command assignment, and correlated completed publication without owning cadence |
| ``RuntimeAssembly`` | Implemented `View`-refining Game Content construction boundary; each assembly is its root UI and owns topology-specific presentation lifecycle, while the App retains one compile-time selection as an opaque value |
| ``RealtimeAssembly`` and ``RealtimeAdvanceDriver`` | Implemented real-time composition constructed from injected Game Content and direct cadence policy, with assembly-owned pause policy, exact requests, coordinated lifecycle, generation-tagged one-shot orbit-command staging, factored toolbar UI, and direct body wiring from `MetalScenePlatformView` to ``InputRuntime``; broader authority recovery and typed routing remain |
| ``Engine``, ``SimulationBehavior``, and ``SimulationSystemSchedule`` | Exact fixed-step scheduler plus controlled Game Content stages inside the Simulation Runtime; every step runs the Engine-owned foundation and contributed systems in one complete ordered schedule |
| ``World`` | Authoritative simulation state inside the Simulation Runtime |
| ``SimulationPresentationSnapshot`` | Latest completed publisher-owned Simulation Runtime presentation value labeled with its exact cursor; its camera is the sole camera authority for the real-time screen |
| ``RenderFrame`` | Current Render-layer private projection that uses one Simulation snapshot and its exact camera |
| ``MetalFrameEncoder`` | Implemented view-independent preparation and encoding against caller-owned textures, `FrameResources`, and an already-begun Metal 4 command buffer; it owns no source sampling, surface, queue submission, presentation, or error policy |
| `MetalSceneView` and `MetalRenderer` | Current MetalKit screen adapter; samples only Simulation presentation, uses its camera exactly, selects ring slots and drawables, submits, presents, and owns screen error policy while delegating reusable encoding |
| ``MetalResourceStore`` | Device-scoped backend owner whose screen caller selects `defaultFrameCount`; compiled target formats remain independent of the adapter |

Future changes should introduce the remaining boundaries incrementally. The direct one-source input connection is not a substitute for typed multi-source routing, route epochs, observer anchors, or multi-output bindings. Offline rendering, snapshot export, replay, and agent control require new deliberate boundaries if they return. Ordered discrete input-transition publication and retained input-event replay are also not part of the implemented latest-snapshot boundary. Add those capabilities only with explicit delivery and storage semantics.

## Related Direction

- <doc:Runtime-Communication>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Game-Content-Architecture>
- <doc:Engine-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
- <doc:Rendering-Architecture>
- <doc:System-Scheduling>
