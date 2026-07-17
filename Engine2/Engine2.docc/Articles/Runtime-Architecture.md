# Runtime Architecture

This article defines the intended top-level application architecture for Engine2 and the vocabulary used to describe communication between its major parts.

## Status

Partially implemented direction.

The current code implements ``InputRuntime`` as the platform-input lifecycle and latest-snapshot publisher, and ``SimulationRuntime`` as the authoritative lifecycle boundary around ``Engine``, ``World``, and ``SimulationLoop``. A complete `RenderRuntime` remains proposed; ``RenderFrame`` and `MetalRenderer` implement important parts of that responsibility today.

## Runtimes Are the Top-Level Application Objects

A **Runtime** is a long-lived application object that:

- owns mutable state for one major capability
- has a meaningful lifecycle
- processes work over time or in response to external activity
- exposes an explicit boundary instead of sharing its internal state

The App owns, connects, starts, and stops its runtimes. Likely runtimes include:

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

## The Simulation Runtime Is Authoritative

The runtimes are peers in ownership and encapsulation, but they are not symmetric in purpose. The **Simulation Runtime** is the authoritative runtime for gameplay state.

The Simulation Runtime owns:

- ``Engine`` and fixed-step accumulation
- ``World`` and authoritative ECS state
- ECS components and resources
- scheduled ``PSystem`` implementations
- simulation ticks

That ownership includes the invariant system schedule. Position, orientation, input consumption, and other mechanics required for a valid simulation remain Simulation Runtime implementation. Future consumer-defined behavior may enter through deliberate extension points, but Game Content does not replace or assemble the simulation's required foundation.

Other runtimes may provide inputs to the Simulation Runtime or project its outputs, but they do not reach into `World` or mutate simulation state directly.

This makes the Simulation Runtime first among peers: it is the semantic center of the game without becoming a global owner of the other runtimes. The Simulation Runtime must remain valid when Render, Audio, Achievement, Storage, or Network runtimes are absent. Outputs for absent consumers simply go unobserved.

## Runtime Independence Does Not Require Equal Usefulness

A runtime is independent when it can be constructed, started, stopped, and tested without hidden access to another runtime's mutable internals. Independence does not mean every runtime is equally useful in isolation.

- An Input Runtime can collect platform input with no active game consuming it.
- A Simulation Runtime can advance with neutral input and no presentation runtimes attached.
- A Render Runtime with no simulation snapshot may draw an empty or loading presentation.
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

The implemented boundary now separates those roles: ``SimulationPresentationSnapshot`` is publisher-owned abstract presentation state, while ``RenderFrame`` is the Render Runtime's private projection. The App connects the read-only latest-value source explicitly. This is one deliberate Simulation Runtime publication, not a universal or exhaustive snapshot of every simulation concern.

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
InputRuntime       -- InputSnapshot                           --> SimulationRuntime
SimulationRuntime  -- SimulationPresentationSnapshot          --> RenderRuntime
SimulationRuntime  -- selected SimulationEvent                --> AudioRuntime
SimulationRuntime  -- selected SimulationEvent                --> AchievementRuntime
```

The arrows show App-owned, explicitly typed wiring, not direct ownership between the runtimes. Rendering consumes the simulation presentation snapshot and derives a private render model; it does not require a simulation event lane. Future continuous audio, networking, tooling, or other needs may justify additional purpose-specific publisher-owned snapshots rather than expanding one universal simulation snapshot.

Engine2 should not connect these publications through a process-global event bus, process-global snapshot database, or runtime service locator. A reusable App-owned router or exchange may eventually implement the connections, but it must preserve the explicit typed topology and may not make arbitrary publishers globally discoverable.

Avoid making directed commands the default peer-to-peer boundary. "AudioRuntime, play this sound" couples the Simulation Runtime to an audio capability. "A weapon fired" states a fact within the Simulation Runtime's authority and allows an optional Audio Runtime to decide how that fact should sound.

Directed request-and-result workflows are still valid when a dependency is intentional, but the App should normally coordinate them. For example, the App can ask a Storage Runtime to load a saved `GameCheckpoint`, then construct or replace the Simulation Runtime with the result. The Simulation Runtime does not need to own or discover the Storage Runtime.

## Runtimes Advance at Different Cadences

There is no single universal application frame.

- Input arrives according to platform event delivery.
- The Simulation Runtime advances in fixed simulation ticks.
- The Render Runtime submits work according to presentation cadence.
- Audio, Network, and Storage runtimes may be event-driven or use their own scheduling policies.

One host update may therefore collect input, execute zero or several simulation ticks, publish one new simulation presentation snapshot, and present zero or several render frames. Runtime boundaries must not assume one-to-one cadence.

The word **tick** refers specifically to one fixed Simulation Runtime simulation advancement. A render frame refers to one presentation attempt. An input snapshot is a revisioned latest value defined by the Input Runtime. ``SimulationLoop`` may sample several input revisions before a tick or the same revision across several host polls; ``Engine`` imports a sampled value only when it actually begins a fixed step.

## ECS Systems Live Inside the Simulation Runtime

An ECS **System** is not a runtime. It is scheduled simulation logic owned by the Simulation Runtime and operating on ``World``.

This distinction keeps the `S` prefix precise:

- `SInputMapping` is an ECS system inside the Simulation Runtime, even though it consumes input.
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
| `InputMetalView` | Platform adapter that submits `InputEvent` values through `PInputEventSink`; it does not call Simulation directly |
| `InputSnapshot`, `InputRevision`, and `PInputSnapshotSource` | Implemented revisioned latest-value boundary containing held state plus cumulative pointer-motion and scroll totals |
| `InputState` and Simulation input systems | Simulation-owned fixed-tick interpretation, action mapping, history, and transient cleanup after snapshot ingestion |
| ``SimulationRuntime`` and ``SimulationLoop`` | Implemented Simulation Runtime lifecycle and host-time polling |
| ``Engine`` | Fixed-step scheduler inside the Simulation Runtime |
| ``World`` | Authoritative simulation state inside the Simulation Runtime |
| ``SimulationPresentationSnapshot`` | Latest completed publisher-owned Simulation Runtime presentation value |
| ``RenderFrame`` | Render Runtime-owned private projection derived from one simulation snapshot and labeled with its source tick |
| `MetalSceneView` and `MetalRenderer` | Early Render Runtime ownership and backend responsibilities |

Future changes should introduce the remaining boundaries incrementally. Ordered discrete input-transition publication and retained input replay are not part of the implemented latest-snapshot boundary. Add those capabilities only with explicit delivery and storage semantics.

## Related Direction

- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
- <doc:Engine-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
- <doc:Rendering-Architecture>
- <doc:System-Scheduling>
