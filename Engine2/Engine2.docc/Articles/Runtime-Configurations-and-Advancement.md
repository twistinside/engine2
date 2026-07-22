# Runtime Configurations and Advancement

This article proposes how Engine2 can assemble different runtime graphs for interactive play, offline rendering, agent control, servers, tests, replays, and deliberately unusual presentation backends without changing the authoritative simulation model.

## Status

Proposed architectural direction.

The existing code already has the most important enabling seams: ``Engine/step(inputSnapshot:)`` can execute one deterministic fixed step, ``SimulationPresentationSnapshot`` is detached from live ECS state, and ``RenderFrame/project(from:)`` is a Render-owned projection. The current ``SimulationRuntime`` still constructs and owns one wall-clock ``SimulationLoop``, however, so only the real-time arrangement is available through the app-facing lifecycle today.

The overall feasibility is high. The work is primarily a separation of pacing, coordination, and exact-result delivery from simulation execution rather than a replacement of the ECS core.

## The Architectural Thesis

Engine2 applications should be explicit assemblies of independently owned runtimes. A configuration selects which runtimes exist, how their typed boundaries connect, and which policy decides when Simulation may advance.

The decisive separation is:

> A configuration-selected **advance authority** decides when and how much progress to request. The Simulation Runtime remains the only owner of what a simulation tick means and the only Runtime permitted to execute one.

The Simulation Runtime continues to own:

- ``World`` and authoritative ECS mutation
- ``Engine`` and the invariant system schedule
- the fixed duration represented by one simulation tick
- serialized, atomic execution of each complete tick
- simulation session and tick identity
- publication of completed Simulation-owned snapshots and events

The active advance authority owns or selects:

- whether requests follow wall time, an offline output timeline, an MCP call, network consensus, a replay record, a test, or manual controls
- how many exact ticks to request
- real-time remainder, catch-up, overload, rate, and pause policy
- how input or semantic control is assigned to tick boundaries
- when a directed workflow should render, encode, inspect, persist, or return a result before requesting more progress

This preserves Simulation authority while allowing its cadence to be completely replaceable.

## Vocabulary

### Runtime Configuration

A **Runtime Configuration** is an App-owned recipe that selects runtime implementations, adapters, typed connections, advancement policy, lifecycle policy, and per-connection delivery policy for a situation.

This term is unrelated to an Xcode build configuration. A Runtime Configuration is also not Game Content: Game Content supplies the entities, rules, descriptions, catalogs, and assets used by selected runtimes, while a Runtime Configuration decides which operational owners exist and how they collaborate.

A configuration has no autonomous cadence merely because it is a recipe. It produces a live assembly that owns the operational objects.

### Runtime Assembly

A **Runtime Assembly** is one live realization of a Runtime Configuration. The App owns the assembly, and the assembly is its explicit transitive ownership mechanism rather than a new globally discoverable runtime. It strongly retains:

- the runtime instances
- adapters and coordinators whose lifetimes are not private implementation details of one retained Runtime
- typed input routes, output bindings, and their active epochs or subscriptions
- connection tasks, subscriptions, and cancellation tokens
- at most one active advance authority for each Simulation Runtime
- lifecycle ordering and failure unwinding

### Runtime Adapters, Sources, and Workers

An **Adapter** translates an external mechanism into one narrow runtime-owned ingress or translates a runtime-owned value into an external mechanism. A keyboard adapter, game-controller adapter, MCP physical-control adapter, and network-control adapter can all feed the Input Runtime without becoming part of its authoritative state.

Adapter lifetime is contextual. An Input Runtime may retain device readers that are intrinsic to its implementation, a view may retain its platform-event adapter, and an assembly may retain a connector between two peer capabilities. Whichever owner constructs an adapter must also make its cancellation and disconnection path explicit.

The reusable principle is **parallel at the edge, serialized at the authority**. Adapters may wait for devices or transport messages concurrently, but the owning Runtime assigns source identity, orders accepted changes, and publishes one coherent boundary value. An adapter must never mutate another Runtime's state directly.

The pattern generalizes, but the roles should keep contextual names rather than conforming to one universal `PRuntimeAdapter` abstraction:

- Input has ingress sources that fan into one input authority.
- Render has output targets or workers that fan immutable work out to one or more backends.
- Network has connections or peers with transport-specific lifecycle.
- Storage has providers or sinks with persistence-specific failure semantics.
- Batch orchestration owns multiple complete Runtime instances rather than disguising independent authorities as adapters inside one Runtime.

These roles share explicit ownership and typed boundaries, not necessarily one lifecycle, direction, concurrency model, or protocol.

### Advance Authority

An **Advance Authority** is the effective authority allowed to decide when a particular Simulation Runtime progresses. A frozen or render-only assembly may have no active authority; whenever progress is permitted, exactly one authority or arbiter must be active.

It is a role, not necessarily one universal type. A real-time driver, an offline capture coordinator, an MCP session coordinator, a network lockstep coordinator, or a deterministic test harness can each fill the role. Multiple request sources are valid only when an explicit arbiter serializes them and becomes the effective authority.

### Advance Driver and Coordinator

An **Advance Driver** translates one cadence source into Simulation advance requests. A real-time driver, for example, converts monotonic elapsed time into an exact number of fixed ticks.

A **Coordinator** deliberately sequences request/result operations across several narrow runtime capabilities. An offline capture coordinator can advance Simulation, render the exact completed snapshot, encode an artifact, and then request the next tick.

Not every small driver or coordinator earns a Runtime boundary. An MCP server with transport state, request lifetime, and an independent lifecycle plausibly earns `MCPRuntime`; a small deterministic test driver remains an ordinary helper. The existing Runtime criteria still apply.

### Simulation Cursor

A **Simulation Cursor** identifies one committed logical position within a continuous Simulation session: a `SimulationSessionID` paired with a ``SimulationTick``.

A bare tick is insufficient because rebuilding or replacing a world currently resets the tick to zero. Exact artifacts, MCP retries, delayed render work, replay branches, and comparisons across sessions need an unambiguous identity.

Every discontinuity that can make the same tick number describe different state must establish a new Simulation session identity. This includes rebuilding, restoring, rewinding, and forking, even when the same ``SimulationRuntime`` object remains alive. If future rollback distinguishes predicted, corrected, and committed histories more richly, the cursor may grow explicit lineage or epoch identity rather than weakening this rule.

The renderer-backed selection direction already proposes `SimulationPresentationID` as the identity carried by a presentation snapshot. That type should wrap or preserve the same session-and-tick cursor rather than introduce a competing identity. `SimulationCursor` names the general advancement/history position; `SimulationPresentationID` names its use on one publication surface.

### Output Timeline

An **Output Timeline** is an offline-job or coordinator-owned scheduling value, such as a movie's frame and shutter schedule. It is not wall time and it is not simulation time. Render owns sampling and quality interpretation; the coordinator maps requested output samples onto completed Simulation cursors without allowing Render to redefine the simulation step.

## Configuration Is Topology Plus Policy

A configuration is more than a collection of quality flags. It selects independent axes:

| Axis | Representative choices |
| --- | --- |
| Session source | New world, generated scenario, checkpoint, replay reconstruction, forked checkpoint |
| Control ingress | Keyboard, controller, pointer, MCP, network, script, bot, replay, none |
| Control vocabulary | Physical device state, mapped player actions, game-semantic commands |
| Control routing | Input-channel assignment, exclusive recipient, deliberate fan-out, partitioned binding, focus and route-epoch policy |
| Advance authority | Wall clock, display wake-up, offline timeline, MCP caller, network barrier, replay, test, fastest possible |
| Progress request | Exact tick, bounded tick batch, target cursor, finite job horizon |
| Output surface | Presentation, audio, network replication, inspection, metrics, state hash, checkpoint |
| Presentation backend | Onscreen Metal, offscreen Metal, text, video, audio-only, physical device, none |
| Delivery semantics | Latest replaceable, exact request/result, ordered buffered, durable journal |
| Cardinality | One Simulation with many consumers, many isolated Simulations, client/server or validation pairs, render-only assembly |
| Lifetime | Continuous application, finite job, request-driven session, one-shot test |
| Backpressure | Drop, coalesce, bound, block the next request, persist |
| Determinism | Best-effort live, recorded external inputs, reproducible exact-step session |
| Execution placement | Framework-required actor, Runtime-owned in-process isolation, helper process, remote transport |

A Runtime boundary is not necessarily a one-to-one mapping to an actor, executor, thread, or thread pool. A configuration may select an implementation or operational placement, while each Runtime remains responsible for the isolation and scheduling of its private mutable state.

These choices must not be accidentally fused:

- onscreen rendering does not imply real-time Simulation
- offscreen rendering does not imply that a Simulation Runtime exists
- MCP input does not imply that MCP owns Render or Simulation
- headless operation does not imply maximum-speed advancement
- a display callback does not imply one render frame per simulation tick
- high render quality does not imply a smaller or variable simulation step

Initially, concrete typed composition functions or configuration types are preferable to a universal runtime-graph DSL. Avoid a mutable dictionary of services, `Any`-typed ports, string-selected runtime classes, or one structure full of optional runtimes and Boolean mode flags. Those approaches hide invalid assemblies until execution.

### Concrete Assembly Shape

Each materially different topology should have a concrete recipe and a concrete live assembly. The exact production APIs remain open, but the construction should be this legible:

```swift
nonisolated struct RealtimeConfiguration: Sendable {
    let simulationSeed: SimulationSeed
    let catchUpPolicy: RealtimeCatchUpPolicy

    @MainActor
    func makeAssembly(
        gameContent: BasicGameContent,
        environment: RealtimeEnvironment
    ) throws -> RealtimeAssembly
}

final class RealtimeAssembly {
    let inputRuntime: InputRuntime
    let simulationRuntime: SimulationRuntime
    let screenRenderRuntime: ScreenRenderRuntime
    let advanceDriver: RealtimeAdvanceDriver
    let inputRoutes: RealtimeInputRoutes

    // The assembly privately retains adapters, connections, and cancellation state.
}
```

The recipe is an immutable transportable value. The illustrative factory is `@MainActor` because today's App constructs UI- and framework-bound objects there; that annotation governs assembly construction, not the execution placement of every Runtime it retains. A headless or otherwise non-UI configuration may construct its assembly from a different isolation domain.

An `OfflineCaptureConfiguration` should produce an `OfflineCaptureAssembly` with an offline coordinator, offscreen Render Runtime, and artifact sink. An `MCPConfiguration` should produce an `MCPAssembly` with transport and agent-session ownership. They may reuse focused construction helpers, but they should not be represented by one `RuntimeAssembly` value containing twenty optional properties.

Three decisions remain separate:

1. **Topology** is expressed by the concrete configuration and assembly type.
2. **Parameters** such as seed, endpoint, resolution, or output path are strongly typed and validated before start.
3. **Selection** happens at the outer App or executable boundary.

A finite App catalog may use a strongly typed enum such as `realtime`, `offlineCapture`, or `mcp`. Tests can construct a concrete configuration directly. Launch arguments or a configuration file can select and populate one recipe at process start. A development UI can stop one assembly and construct another through the coordinated transition described below. Materially different deployment and entitlement needs may justify separate executables that call the same builders. A Runtime Configuration is therefore not synonymous with an app target, command-line flag, or in-app mode; those are selection mechanisms around the same typed composition model.

Engine consumers must be able to define their own concrete assemblies without extending a closed Engine2-wide enum.

### Cardinality Belongs to the Assembly

The default ownership unit is one authoritative Simulation session per ``SimulationRuntime``. A Monte Carlo, reinforcement-learning, validation, or branching configuration creates several isolated Simulation Runtime instances and lets an App-owned batch coordinator schedule them. This keeps each World, cursor, request gate, publication set, and failure boundary unambiguous.

A future `SimulationHostRuntime` or session pool may earn a boundary when shared worker management creates concrete lifecycle or scheduling value. It should still expose session-qualified capabilities and preserve per-session isolation. Different seeds are not adapters inside one mutable Simulation Runtime, and a single Runtime should not silently multiplex independent Worlds merely because they execute similar code.

Configurations select among declared typed capabilities and may choose per-connection buffering, retention, and backpressure policy where the publisher's contract permits it. They do not redefine publisher-owned vocabulary or reinterpret a latest-value source as an exact result or durable journal.

## Advancement Is a Directed Boundary

Snapshots and events are consumer-agnostic publications. Advancing Simulation is different: it is a deliberate command with a correlated result.

The Simulation Runtime should eventually expose a narrow, Simulation-owned advance capability. The exact API remains proposed, but its semantic shape should resemble:

```swift
nonisolated struct SimulationSessionID: Hashable, Sendable {
    let rawValue: UUID
}

nonisolated struct SimulationCursor: Hashable, Sendable {
    let sessionID: SimulationSessionID
    let tick: SimulationTick
}

nonisolated struct SimulationStepCount: Hashable, Sendable {
    // Construction validates that rawValue is greater than zero.
    let rawValue: UInt32
}

nonisolated struct SimulationCompletedStepCount: Hashable, Sendable {
    // Zero is valid when interruption occurs before the first requested tick.
    let rawValue: UInt32
}

nonisolated struct SimulationAdvanceRequest: Sendable {
    let expectedCursor: SimulationCursor?
    let stepCount: SimulationStepCount
}

nonisolated struct SimulationAdvanceResult: Sendable {
    let initialCursor: SimulationCursor
    let finalCursor: SimulationCursor
    let completedStepCount: SimulationCompletedStepCount
    let finalPresentationSnapshot: SimulationPresentationSnapshot
}

nonisolated enum SimulationAdvanceOutcome: Sendable {
    case completed(SimulationAdvanceResult)
    case interrupted(SimulationAdvanceResult, SimulationAdvanceStopReason)
    case rejected(currentCursor: SimulationCursor, SimulationAdvanceRejection)
}

nonisolated protocol PSimulationAdvanceTarget: AnyObject, Sendable {
    func advance(_ request: SimulationAdvanceRequest) async -> SimulationAdvanceOutcome
}
```

These names and fields are illustrative. The value declarations and protocol are explicitly `nonisolated` so they do not inherit the app target's current default `MainActor` isolation. The App may construct and retain the capability on `MainActor` without making main-actor execution part of the capability's semantics. `Sendable` makes transfer of the target capability and boundary values part of the contract. A concrete implementation may remain on `MainActor` during migration, use its own actor, or provide another concurrency-safe implementation. Existing ``SimulationTick``, ``SimulationPresentationSnapshot``, and the rest of their complete value graphs still need explicit concurrency review, `nonisolated` treatment where required, and `Sendable` conformance before this sketch compiles as written. Neither `async`, `Sendable`, nor actor isolation by itself establishes the request-ordering rules below.

The request deliberately omits one universal control payload. For the current physical-input vertical slice, the active Simulation Input Route captures a coherent, consumer-specific assignment from an immutable ``InputSnapshot``. The advance driver submits that routed assignment through the same typed Simulation Runtime advance operation. The Runtime validates its channel, route epoch, recipient, and baseline attribution, imports it only at the safe tick boundary, privately calls ``Engine/step(inputSnapshot:)``, commits publications, and returns the correlated result. Neither the driver nor Simulation holds the raw ``PInputSnapshotSource`` and bypasses routing, and the proposed Runtime does not retain a weak live Input source whose value can change independently of the request.

Replay, networking, bots, or Game Content may later require tick-addressed semantic control batches. Those should use a Simulation-owned typed control surface or a deliberate evolution of the request rather than making keyboard-shaped state the permanent command vocabulary. Whatever the selected ingress, the controls consumed by a tick must be attributable to its advance request.

For a multi-step physical-input request carrying one routed snapshot assignment, the baseline policy imports that snapshot before the first requested tick: that Simulation consumer derives cumulative pointer and scroll transients once for the first tick, while held state remains available to later ticks. The immutable snapshot remains available to other routed recipients with independent baselines. A batch that changes controls between ticks requires an explicit tick-addressed schedule. Exact results or an accompanying journal should eventually identify the input publisher, channel, route epoch, revision, or semantic-control identities consumed by the committed cursor range.

`SimulationStepCount` is strictly positive. Reading the current cursor, presentation, or observation without advancing is a separate capability rather than a zero-step command with hidden side effects.

The required advancement semantics are more important than the illustrative API:

- a request asks for an exact, strongly typed number of fixed steps rather than supplying an arbitrary floating-point delta
- Simulation validates the expected cursor when one is supplied
- only one tick mutates the world at a time
- one tick cannot suspend halfway through its system schedule
- Simulation does not acknowledge or publish a completed tick until the entire schedule returns
- an outcome reports exactly how much work committed before success or an interruption observed between ticks
- exact workflows can retain an immutable value from the requested cursor rather than racing a changing latest-value slot

The current in-place ECS is not a transactional rollback system. A process trap or future thrown failure halfway through system execution cannot truthfully be described as “the tick never happened”; recoverable rollback would require staging, undo, or checkpoint restoration. The achievable near-term guarantee is that no `await`, cooperative cancellation, successful receipt, or completed publication occurs in the middle of a tick. Bounded-batch cancellation and ordinary stoppage are observed between ticks, and a structured interrupted outcome reports the last fully completed cursor. If a future recoverable error escapes halfway through a tick, the Runtime must invalidate that session or restore a known checkpoint before accepting more work; it must not report the previous cursor while continuing from a partially mutated ``World``.

Only one advance request may be active per Simulation session. The ticks committed by one bounded request form a contiguous cursor range. If the implementation cooperatively yields between ticks for fairness or cancellation, it must keep a non-reentrant request gate so another `advance` call cannot interleave. Cross-runtime rendering or encoding pressure belongs between separate advance requests, not inside a partially coordinated batch.

Returning the final presentation value is one possible initial exact-result design, not a requirement that every future Simulation output be packed into one result. Agent observation, network replication, checkpoints, metrics, and other semantic surfaces should remain deliberately named capabilities.

A batch also need not materialize every large snapshot surface after every internal tick. Simulation completes every tick and preserves the ordering guarantees of any required event lane, while each snapshot contract defines whether it captures the final batch cursor, selected cursors, or every tick. An offline coordinator places batch boundaries at every output sample it must render exactly.

A cursor identifies one committed position; it does not imply that the corresponding state is still retained, seekable, or recoverable. Exact rendering or retry requires a returned immutable value or an explicit cursor-addressed retention/rendezvous policy.

## The Exact-Step Primitive Comes First

The portable advancement primitive should be one exact fixed step. Bounded batching is an optimization layered over that primitive.

Real-time elapsed-time accumulation belongs outside the Simulation core:

```text
monotonic elapsed time
        |
        v
Realtime advance policy
  remainder + catch-up cap
        |
        v
exact Simulation step requests
```

This means the Simulation Runtime still defines the duration and meaning of one tick, while a real-time driver decides how many such ticks current wall time permits. Offline, MCP, replay, lockstep, and tests can issue exact requests without pretending that wall time passed.

The current ``Engine/update(deltaTime:inputSnapshot:)`` and ``SimulationLoop`` combine these responsibilities for today's real-time application. ``Engine/step(inputSnapshot:)`` already demonstrates that extraction is practical.

## A Simulation Tick Is Indivisible

Each tick committed by a Simulation advance executes one complete invariant fixed-step schedule. Configuration chooses whether and when to request that operation; it does not select an arbitrary subset of systems for the operation to run.

Engine2 should not expose a general `step(mode:)`, public system mask, `cameraOnly` tick, or configuration-defined schedule bucket. Partial execution would give ``SimulationTick`` several meanings and make snapshots, events, deterministic replay, MCP results, and system invariants depend on an implicit run mode. A completed cursor must mean that the whole authoritative schedule committed.

If a genuinely different authoritative operation later appears, it should receive a separately named capability with its own invariants, identity, publications, and tests. It should not increment ``SimulationTick`` while doing less than a Simulation tick.

The current two-list schedule is therefore a transitional implementation, not the target configuration surface:

| Current always-running work | Target disposition |
| --- | --- |
| ``SInputMapping`` | Simulation-domain mapping becomes an invariant early input-mapping stage within every complete tick; presentation-view bindings leave Simulation. |
| ``SCameraInput`` | Free-orbit presentation control moves to a view-owned controller. Only gameplay-authoritative camera behavior remains in the complete Simulation schedule. |
| ``SInputHistory`` | Simulation-consumed history runs on complete ticks; host or device diagnostics belong to Input Runtime or App tooling. |
| ``SInputCleanup`` | Transient cleanup becomes an invariant final stage before every complete tick commits. |
| Metrics and tracing | Observe requests, completed publications, and results without requiring a partial ECS mutation pass. |

Ordinary frozen pause means the absence of advance requests and no cursor change. A future game-specific **soft pause** can remain authoritative game state processed by the complete schedule—for example, movement may stop while network/session rules, scripted world state, or explicitly pause-exempt entities continue. Menu UI and other presentation can progress independently without making a partial Simulation tick. Soft pause is not implemented by suppressing an arbitrary engine system list.

## Input Must Be Attributable to Ticks

Current ``InputSnapshot`` semantics are useful across several configurations: held state persists, and cumulative pointer/scroll totals let Simulation derive motion across skipped publisher revisions. An MCP adapter can initially submit the same `InputEvent` values as the platform adapter and then request a tick.

That is not the only control boundary Engine2 will ever need. Three levels should remain distinct:

1. raw host ingress such as keyboard, pointer, controller, or text callbacks
2. revisioned device state published by an Input Runtime
3. tick-addressed player actions or game-semantic commands accepted at the Simulation boundary

MCP, bots, replays, network peers, and tests may eventually prefer semantic commands rather than impersonating a keyboard. Do not expand physical `InputEvent` into a universal command bag to serve those uses.

### Multiple Sources Converge at One Input Authority

Input sources may collect work concurrently, but ``InputRuntime`` owns the serialized acceptance order, canonical device state, publication session and revision, and coherent snapshot. The configuration supplies source-to-input-channel assignment and merge policy; adapters do not mutate one shared pressed-key set directly. An input-domain channel groups sources into one logical control surface without deciding which player, window, or viewpoint will consume it.

```text
InputMetalView ------------------+
controller source --------------+--> InputRuntime --> InputSnapshot
MCP physical-control connector --+
bot physical-control source -----+
                       concurrent ingress
                       serialized acceptance
```

Multi-source ingress requires stable source identity and source-local held state. If two sources hold the same key, releasing it from one source must not erase the other's contribution. Detaching or restarting a source neutralizes only that source. Axis combination, pointer ownership, source-to-channel assignment, source priority, and human-versus-bot takeover all require explicit policies; arrival order alone is not a merge policy.

The Input Runtime assigns its own publication revision after accepting and merging source changes. Source-local sequence identities may additionally support deduplication, diagnostics, and replay. A deterministic configuration records the accepted total order whenever concurrent arrival can affect the result.

Input Runtime normalization stops at input-domain state. Simulation-owned mapping converts imported input into player or other gameplay concepts at the fixed-tick boundary. Presentation viewpoint control may map the same input through its own recipient-domain bindings. A complete MCP or Network service with transport, authentication, and session lifetime remains a peer Runtime; only a deliberately configured physical-control connector participates in Input Runtime fan-in. Semantic commands may instead enter through a separately named Simulation-owned control boundary.

Batch advancement must define its input behavior. “Apply this input and advance 30 ticks” is ambiguous unless the contract states whether a transition occurs once, held state persists, an action repeats every tick, or a distinct per-tick control schedule is supplied. One-step requests are the unambiguous baseline; an optimized batch should carry explicit input scheduling semantics.

Publisher revisions from independent Runtime instances cannot be merged by choosing the numerically newest value. Multiple producers normally converge through one designated Input Runtime. If an App-owned arbiter combines several Input Runtime publications, it becomes the effective input authority with its own publisher/session identity and emits one coherent, source-attributed publication through a typed boundary. An ordinary Input Route never mints or compares revisions from unrelated publishers.

The current ``InputSnapshot`` is a single-channel vertical slice. A future multi-seat contract may expose source-partitioned state, channel-addressed snapshots, or several typed output capabilities. It must preserve every identity required by configured routes rather than flattening several players into one aggregate and asking downstream consumers to reconstruct ownership.

### Input Authority, Routing, and Interpretation Are Distinct

“Who owns input?” has three answers at three boundaries:

1. The **Input Runtime** owns source identity, serialized acceptance, canonical input-domain state, publication sessions and revisions, and coherent immutable input values.
2. The **Runtime Assembly** owns typed **Input Routes** that decide which input-domain channels or control lanes reach which recipient capabilities.
3. Each **recipient** owns interpretation. Simulation maps routed controls into authoritative player or gameplay concepts at a fixed-tick boundary. A presentation viewpoint controller maps routed controls into an output-specific viewpoint. UI, editor, accessibility, and tooling recipients define their own command vocabularies.

```text
hardware, MCP physical-control, and bot adapters
                    |
                    v
              InputRuntime
        source-attributed input state
                    |
                    v
          App-owned Input Routes
             /             \
            v               v
  Simulation control   ViewpointController
  player/game mapping  presentation mapping
            |               |
            v               v
  authoritative state  immutable viewpoint ---> Render
```

Render normally consumes an immutable scene value, a resolved viewpoint, and Render-owned settings. Audio consumes immutable listener state and ordered audio occurrences. Neither Runtime consumes raw input, clears Simulation input, or gains gameplay authority merely because a common real-time assembly binds one player to one screen and listener.

An **exclusive route** assigns a control lane to one recipient for its active route epoch. Relative pointer motion, text entry, a captured controller, and photo-mode orbit commonly require exclusivity so one gesture does not also steer gameplay. A **shared route** deliberately lets several recipients observe the same immutable publication, for example diagnostics, accessibility behavior, or a tracking source whose latest pose serves both authoritative and late-presentation needs. A partitioned policy may route distinct controls from one channel to different recipients. Sharing or partitioning must be explicit rather than an accidental consequence of several objects polling the same source.

Input source, input channel, Simulation player or observer, window or viewport, output, viewpoint, and Simulation-session identities remain distinct. One player may use several sources. Moving a source between input channels is an Input Runtime transition that removes its held contribution from the old channel and establishes it in the new one. Rebinding a channel to another player, observer, viewport, or viewpoint is an assembly transition that creates a new route epoch and recipient baseline. Several windows may follow one player, one window may switch observers, and a spectator viewpoint may have no player. A configuration expresses those relationships rather than inferring them from focus, array position, or one global camera.

An ``InputSnapshot`` is a non-destructive publication. Reading or importing it does not acknowledge data to ``InputRuntime`` or consume motion on behalf of another recipient. Each route-and-recipient pair keeps a private consumer baseline scoped by input publisher identity, publication session, input channel, route identity and epoch, and recipient target/session. Its ``InputRevision`` and cumulative totals have meaning only inside that scope. Re-reading one revision produces no new delta for that recipient, while another recipient derives its own delta independently. The current Simulation-owned ``InputState`` already demonstrates the local revision-and-total mechanism for one publisher and channel; a viewpoint controller needs the same local-cursor rule, while the future route contract supplies the missing scope identities.

Creating, retargeting, suspending, or resuming a route establishes a new route epoch and an explicit baseline against the latest publication. Historical pointer and scroll totals normally do not replay. The route policy also decides whether currently held controls are inherited, neutralized, or ignored until released. The transition produces an immutable baseline/neutralization assignment that the recipient applies through its own typed boundary: Simulation applies it at a safe advance boundary, while a Viewpoint Controller applies it within its own state isolation. The App never reaches into ``InputState`` or mutates a recipient cursor directly. Delayed delivery from an older route epoch cannot affect the new recipient. Rebasing one route never resets ``InputRuntime`` or advances another recipient's cursor.

Each transition also establishes an explicit cutover at an Input publisher revision and, when an ordered lane exists, an event-sequence boundary. Changes accepted before and after that boundary follow the old and new route policies respectively. Epoch checking rejects delayed delivery, but does not replace this cutover rule. If handoff deliberately drops or coalesces input, that behavior is part of the declared transition policy.

The future exact-advance path must preserve this construction rule. A newly attached Simulation route explicitly chooses a current-publication rebase or deliberate session-start replay, then submits that immutable assignment with the first request; it must not accidentally ingest the entire cumulative pointer and scroll history merely because the Runtime no longer retains a live Input source.

## There Is At Most One Effective Advance Authority

At most one effective authority may issue progress requests for a Simulation session, and exactly one must be active whenever progress is permitted. Actor serialization alone is not sufficient: two logically independent drivers can still create nondeterministic ordering even if their calls never overlap.

A development assembly can expose real-time, manual-step, and MCP controls together only if one coordinator arbitrates them. For example, it may suspend real-time demand while an MCP transaction owns a temporary manual-step lease, then explicitly rebase wall-clock timing before resuming.

This also clarifies pause:

- pausing the advance authority means no new simulation ticks occur
- stopping a Runtime is a lifecycle operation
- rendering, inspection, encoding, input collection, and other peer-runtime work may continue while Simulation is paused
- a game-specific soft pause, when needed, remains state processed by complete ticks rather than a partial schedule

Every pause policy must also state what happens to input revisions accumulated while no ticks occur. A configuration may ingest them on resume, rebase and discard transient totals, neutralize controls, or journal tick-addressed transitions. Rebasing wall-clock time alone does not resolve accumulated input.

The current `pauseSimulation()` leaves ``SimulationLoop`` active, runs always systems, and advances tick identity while simulation-gated systems are disabled. This makes camera input usable in the prototype, but gives one tick two meanings. The target design retires that coupling: frozen Simulation stops ticking, presentation viewpoint control continues on its own cadence, and the current always-running work is reclassified as described above.

## Publications and Exact Results Serve Different Work

Engine2 needs several explicit boundary shapes rather than one universal bus:

| Boundary | Semantics | Typical use |
| --- | --- | --- |
| Latest snapshot | Newest completed value replaces older values | Onscreen rendering, slow displays, dashboards |
| Ordered event lane | Per-publisher order with explicit buffer/drop policy | Audio occurrences, achievements, recorders |
| Exact request/result | Caller awaits a value correlated to its command | Simulation advance, offscreen render, MCP response |
| Durable journal | Explicit retained history and cursoring | Replay, auditing, rollback, time travel |

Cumulative input snapshots recover aggregate pointer/scroll motion and current held state across skipped publications within one publisher session; totals restart when the ``InputRevision`` session changes. They do not recover the order or multiplicity of discrete transitions. A future ordered Input event lane is a broadcast publication with an independent sequence position and cancellation lifetime for each subscription, plus explicit buffering and overflow policy for each connection. Storage may be shared or per subscription; one subscriber advancing or dropping its position must not advance another subscriber. When a consumer needs a coherent snapshot followed by ordered transitions, the publisher correlates the snapshot revision with an event-sequence boundary. Retained replay is a deliberate journal policy, not an accidental property of the live lane.

``PSimulationPresentationSource`` is intentionally a latest-value boundary. That is correct for a display renderer that can skip superseded states. It is insufficient by itself for an offline frame job or an MCP operation that must render exactly the state produced by its own advance request.

An exact workflow must receive or retain the immutable snapshot associated with the completed cursor. It must not advance, read `latestPresentationSnapshot` after an unrelated caller has changed it, and silently render the wrong state.

Likewise, a multi-tick advance must not imply that events from intermediate ticks are safely recoverable from the final snapshot. A workflow that needs every occurrence must use an ordered lane or explicit journal with a result cursor.

Backpressure belongs to each connection:

- a real-time display normally drops superseded snapshots rather than stalling Simulation
- an archival offline renderer intentionally prevents the coordinator from requesting the next required tick until the exact frame is safe
- a cloud video stream may drop stale encoded frames to protect latency
- a replay recorder may fail or stop advancement rather than lose required history
- an MCP operation may bound work, return partial completed progress, and allow a later request to continue

Simulation must not await cross-runtime work from inside a world mutation. Backpressure is applied after a completed tick and before the next request.

## Realtime Interactive Configuration

The current application becomes the first configuration, not the universal application shape. Its target connections make input routing and output binding explicit:

```text
AppKit adapters ---> InputRuntime
                         |
                         +-- Simulation Input Route --+
                         |                            +--> RealtimeAdvanceDriver --> Simulation
monotonic clock ---------------------------------------+
                         |
                         +-- Presentation Input Route ----> ViewpointController

Simulation -----------> scene + observer anchors -----+
ViewpointController ---> presentation viewpoint -------+--> Viewpoint binding --> ScreenRenderRuntime

Simulation -----------> listener anchors ----------------> Listener binding --> Audio output
```

In the ordinary locked player view, the authoritative control lane targets Simulation and the viewpoint binding follows the resulting Simulation-authored observer anchor; no presentation controller interprets the same look input again. A free photo or replay view uses an exclusive presentation route while the corresponding gameplay route is neutralized. A third-person or orbit presentation may instead partition one input channel so movement or authoritative aim reaches Simulation while camera-orbit controls reach the Viewpoint Controller. Deliberate shared delivery remains possible only when the configuration names it.

The real-time driver owns:

- clock sampling
- elapsed-time remainder
- catch-up and maximum-step policy
- backlog overflow policy
- requesting a consumer-specific assignment from the active Simulation Input Route at advance boundaries
- suspending and rebasing wall time around app inactivity

The Screen Render Runtime draws according to surface availability or display cadence. It may render the same completed snapshot more than once, skip intermediate snapshots, or interpolate private presentation state. It does not become the advance authority merely because a display callback woke the App.

## High-Quality Offline Configuration

“The renderer ticks Simulation” is useful workflow shorthand, but Render should not own or call Simulation directly. The App-owned offline coordinator intentionally depends on narrow advance and render request/result capabilities:

```text
script, replay, or authored timeline
                  |
                  v
       OfflineCaptureCoordinator
             |
             +-- advance request ------------------> SimulationRuntime
             <-- exact cursor + immutable snapshot -+
             |
             +-- render(snapshot, viewpoint, settings) -> OffscreenRenderRuntime
             <-- rendered output -------------------+
             |
             +-- encode / write -------------------> ArtifactSink
             <-- completion -------------------------+
             |
             +-- serial policy may permit the next required step
```

The coordinator can hold Simulation at one cursor while Render:

- accumulates thousands of samples
- renders the same immutable scene from several explicit viewpoints
- produces multiple resolutions or diagnostic passes
- encodes a high-dynamic-range master and a smaller JPEG observation proxy
- retries an export without re-running Simulation

This can be intentional backpressure between complete operations, not shared ownership. A bounded serial job waits for its artifact before requesting more progress. Another configuration may retain several exact immutable snapshots and pipeline bounded render jobs while Simulation advances ahead. GPU work always proceeds from immutable values and never holds a lock on ``World``; serial versus pipelined behavior is an explicit configuration policy.

### Output Time Is Not Simulation Time

A 60 Hz Simulation and a 24 fps movie do not have an integral one-tick/one-frame relationship. The offline timeline should use exact tick or rational media-time arithmetic to select:

- the completed tick before a sample time
- the following tick when interpolation is supported
- a presentation-owned interpolation fraction
- several shutter sample times when motion blur requires them

Render may interpolate immutable presentation values. It must not privately half-step the ECS, vary the Simulation fixed delta, or read a live world. Selecting a smaller Simulation fixed step is an explicit session choice that changes simulation behavior and therefore identifies a different run.

## Scene Authority and Viewpoint Authority Are Distinct

“Camera” does not imply one universal owner.

Simulation owns camera-related facts when they are authoritative Simulation state or canonical Simulation-authored presentation facts whose evolution is tied to complete ticks. Examples include player aim, a gameplay-significant camera rig, a simulated sensor, a scripted camera synchronized to the world, or a canonical camera anchor/default viewpoint published with completed presentation state.

An output-specific **viewpoint** is different. A free-orbit camera, photo-mode view, editor viewport, spectator view, minimap, split-screen view, MCP inspection view, or offline camera track selects how one consumer observes an immutable scene. Its owner is the presentation assembly, view controller, capture coordinator, tracking Runtime, or other policy that selects that output. Render owns final projection and backend work, but it need not originate every viewpoint it consumes.

Render settings such as exposure, accumulation, depth of field, shutter sampling, resolution, and diagnostic output remain Render-owned policy.

The current `World.camera`, ``SCameraInput``, singular camera in ``SimulationPresentationSnapshot``, and implicit use of that camera by ``RenderFrame/project(from:)`` form a practical first implementation. They should not become a requirement that every render of a Simulation snapshot use one Simulation-mutated camera. The long-term semantic boundary is:

```text
immutable scene state + explicit viewpoint + render settings
                              |
                              v
                         render result
```

A Simulation-published camera can remain the default when a configuration supplies no override. The exact viewpoint type and whether a screen assembly retains an ordinary controller or eventually earns a dedicated Runtime should follow concrete implementation needs.

### Simulation Observers Publish Anchors, Not Output Cameras

One Simulation session may contain many authoritative observers. Eight players do not require eight Simulation Runtimes: one ``World`` can contain eight player or observer identities and publish completed observer-relative facts for each.

A **Simulation-authored presentation anchor** is a tick-qualified, backend-neutral value derived from authoritative Simulation state. An observer may publish typed anchors such as a head pose, vehicle pose, canonical view origin, sensor origin, or listener origin. An anchor may carry the transform, velocity, and semantic facts needed to derive presentation, but it contains no Render Runtime, Audio Runtime, surface, speaker, input route, or backend-resource identity.

```text
authoritative player or observer state
                    |
                    v
          completed Simulation tick
                    |
                    v
       observer identity + typed anchors
```

An anchor is a one-way publication boundary. It may derive from the same authoritative aim, pose, or perception state used by Simulation systems, but optional consumers never write projected results back into that state.

Observer-specific information rules remain authoritative. If fog of war, secrecy, replication interest, or another game rule determines which facts a player may receive, Simulation or Network publication enforces that rule deliberately. Frustum culling, visual occlusion optimization, mix selection, and output composition remain consumer-private work.

### Output Bindings Are Modality-Specific

The Runtime Assembly binds each output to a Simulation-authored anchor or an independently controlled presentation value:

```text
Simulation observer anchor
       |                         |
       v                         v
Viewpoint resolver          Listener resolver
       |                         |
       v                         v
screen/offscreen Render     Audio output or stream

free ViewpointController ---> independent presentation binding
```

A render viewpoint and an audio listener are distinct immutable values even when both derive from the same player anchor. Render may add projection, interpolation, tracking pose, or a presentation-only offset. Audio may use anchor velocity and orientation with Audio-owned spatialization policy. Neither modality owns the authoritative observer.

An output shared by several observers still requires a finite modality-specific policy. A window may compose several viewports. One physical audio mix may select one listener, produce separate listener-specific streams, or apply an explicitly designed combined-listener model; several observers never implicitly collapse into one listener transform.

The common real-time one-player arrangement is a simple pair of bindings: player input routes to Simulation, Simulation updates the authoritative observer, and one screen viewpoint plus one audio listener follow its published anchors. Render and Audio never need the raw input. That one-to-one shape is a configuration convenience, not an identity rule. One observer may drive several windows or streams, several observers may feed separate outputs, an output may switch observers, and Render and Audio may intentionally follow different anchors.

### Gameplay Perception Is Not Presentation Feedback

AI vision, gameplay hearing, aim, visibility rules, and other mechanics remain Simulation-owned perception. They operate on explicit components, resources, sensors, queries, or events inside the complete Simulation schedule.

If an AI reacts to a player's gaze or sensor, that gaze or sensor is authoritative Simulation state and a presentation anchor is derived from it. The AI does not inspect a resolved render camera. Likewise, Audio may spatialize a sound for a listener, but AI hearing is modeled by Simulation. Removing an optional Render or Audio Runtime must never change gameplay behavior.

If AI or another gameplay system should react to a presentation-controlled view, that is an explicit design change: the relevant pose must enter Simulation through a typed command and become authoritative on a subsequent tick. Renderer-private or viewpoint-controller state never influences Simulation implicitly.

### Photo Mode Without Simulation Ticks

Photo mode freezes the Simulation cursor while presentation work continues:

```text
InputRuntime ---> active presentation Input Route ---> ViewpointController
                                                          |
frozen Simulation presentation --------------------------+--> Screen or Offscreen Render
```

The viewpoint controller consumes routed presentation controls, updates or publishes an immutable resolved viewpoint, and may process orbit, zoom, lens, or framing according to presentation input or render cadence. Render consumes that value and redraws the same immutable Simulation state without reading Input Runtime or requesting a Simulation tick.

Entering photo mode begins a new exclusive presentation-route epoch and sends the viewpoint controller a current-publication baseline through its typed route boundary. The suspended Simulation route does not accumulate a private backlog merely because Input Runtime continues publishing. Leaving photo mode closes the presentation route and creates a baseline/neutralization assignment for Simulation; Simulation applies it at the next safe advance boundary before executing another tick. That assignment discards photo-mode transients and carries the configuration's held-control reacquisition policy. With several windows, each route additionally carries window or viewport and viewpoint identity rather than merging all pointer motion into one global camera.

An MCP assembly uses the same separation: Codex may set or orbit a viewpoint and request several images from one stable Simulation cursor before deciding whether to advance.

### Replay Chooses an Output Binding

Replay state and replay viewpoint are separate choices:

| Replay view | Source | Meaning |
| --- | --- | --- |
| Exact recorded view | Recorded presentation-viewpoint lane, when deliberately captured | Reproduces output-specific camera state correlated with the recorded cursor or media timeline |
| Observer-follow view | Replayed Simulation observer anchor plus a selected presentation rig | Follows a player or sensor without necessarily reproducing original smoothing, tracking pose, field of view, or framing |
| Free view | Replay-viewer-owned viewpoint controller | Uses live presentation input without mutating replayed Simulation state or changing its cursor |

An observer anchor alone cannot reproduce exactly what a player saw when smoothing, tracking pose, projection, field of view, aspect-dependent framing, or other presentation state was local. Exact reproduction requires those values in the recorded presentation-viewpoint lane.

When replay reconstructs a live Simulation, the replay journal remains the only control source advancing authoritative state in free-view mode. A snapshot-only replay viewer has no authoritative Simulation to advance. Switching between follow and free view—or leaving replay—begins a new route epoch, establishes a private input baseline, applies the declared held-control policy, and rejects delayed delivery from older epochs. Allowing live input to change authoritative replay state creates a branch or fork with a new Simulation lineage; it is not a camera-mode toggle.

Audio binding remains independent of replay camera mode. A replay may keep its listener attached to a recorded player while Render moves freely, bind the listener to the free view, or select another explicit policy. Changing render viewpoint never silently rebinds Audio.

### Multi-Camera Rendering

Multi-camera rendering pairs one exact immutable scene value with several explicit viewpoints. The coordinator may obtain them from an authored camera track, named Simulation-published anchors, per-output configuration, an MCP request, or generated dataset parameters. A serial policy renders every required view before requesting the next Simulation step. A bounded pipeline may retain the exact scene value and advance while its views render. Neither policy mutates Simulation once per camera.

Artifacts produced this way identify at least the source Simulation cursor, viewpoint identity or revision, and render-settings identity. A Simulation cursor alone cannot distinguish images rendered from different viewpoints while gameplay remains frozen.

## MCP and Codex-Controlled Configuration

An MCP configuration separates transport, control, Simulation, and rendering:

```text
Codex tool call
      |
      v
 MCPRuntime ---------------- transport, authentication, request lifetime
      |
      v
 AgentSessionCoordinator --- serialization, idempotency, work bounds
      |
      +-- stage/read controls --------------------> InputRuntime
      <-- coherent input revision or staged batch -+
      |
      +-- advance(expected cursor, control) -----> SimulationRuntime
      <-- exact cursor + immutable snapshot -------+
      |
      +-- render(snapshot, viewpoint, settings) -> OffscreenRenderRuntime
      <-- JPEG / PNG artifact ---------------------+
      |
      +-- correlated tool result ----------------> MCPRuntime --> Codex
```

Useful operations include:

- create, reset, or load a named session with an explicit seed/configuration
- press, release, or set physical controls
- submit a game-semantic action when that boundary exists
- advance one or a bounded number of exact ticks
- inspect a deliberate structured observation surface
- render the current exact cursor
- perform a serialized advance-and-render workflow
- create a checkpoint or fork a lineage when those capabilities exist

The absence of a tool call means no Simulation progress in this configuration. Codex may think for seconds or hours; the Simulation cursor remains stable.

### MCP Correctness Requirements

Remote tools retry, callers disconnect, and requests can overlap. An agent coordinator therefore needs stronger correlation than an in-process button:

- a request or idempotency identity so a retry does not double-advance
- an optional expected Simulation cursor for optimistic concurrency
- a maximum step count or work budget per call
- chunking and cancellation only between committed ticks
- a result that reports the exact final cursor even after partial completion
- serialization so input, advancement, inspection, and capture from different clients cannot interleave accidentally
- artifact metadata containing at least the Simulation cursor, resolved viewpoint identity or revision, render-settings identity, and content identity

An advance-and-render operation is a workflow, not a rollback transaction. If Simulation advances successfully and JPEG encoding later fails, the response should report the new cursor. The coordinator can retry rendering the retained exact snapshot instead of silently advancing again.

JPEG is valuable as a Codex-readable observation, but it should not be the only machine-readable output. A purpose-specific agent or inspection snapshot can expose structured state, selected events, terminal conditions, or deterministic hashes without turning ``SimulationPresentationSnapshot`` into a copy of all ECS state.

## Broader Configuration Space

The same ownership model supports many arrangements.

### Interactive and Presentation-Led

| Configuration | Advance authority | Notable topology |
| --- | --- | --- |
| Desktop real time | Monotonic real-time driver | Device input, fixed Simulation, latest screen render, optional audio |
| Display-woken real time | Real-time driver awakened by display callbacks | Elapsed time still maps to fixed ticks; frame and tick remain independent |
| Manual debugger | Debug coordinator | Pause, step one or N ticks, inspect exact results, redraw one snapshot repeatedly |
| Photo mode | No active Simulation advancement | A frozen scene is redrawn from an independently controlled viewpoint without changing the Simulation cursor |
| Multi-window live play | Real-time driver | One Simulation publishes several observer anchors; the assembly binds each screen and audio output independently |
| Local or streamed multiplayer | Real-time or server driver | Several Simulation observers publish anchors; render and audio outputs may be one-to-one, omitted, remote, or resolved by an explicit shared-output policy |
| AR or VR | Real-time driver | Simulation remains fixed-step; tracking/presentation owns late pose, which Render consumes for late projection or prediction |

### Offline, Batch, and Content Work

| Configuration | Advance authority | Notable topology |
| --- | --- | --- |
| Cinematic capture | Offline output timeline | Exact snapshots, path tracing, image sequence or video encoding |
| Multi-camera capture | Offline coordinator | One exact scene value is paired with several explicit viewpoints before the coordinator requests the next step |
| Deterministic re-render | Replay coordinator or none | Re-simulate from checkpoint/input or render recorded presentation snapshots directly |
| Asset preview | None | Game Content render descriptions feed Render without a live Simulation Runtime |
| Thumbnail farm | Batch coordinator | Many isolated render-only or short Simulation assemblies |
| Dataset generation | Batch coordinator | Images, masks, depth, labels, and structured ground truth share exact cursor identity |
| Monte Carlo simulation | Fast bounded driver | Many seeded Simulation sessions, metrics output, no renderer required |
| Benchmark or fuzz | Fast/test driver | Exact tick horizon, sampled publications, recorded failing seed and inputs |

### Agent, Tooling, and Turn-Based

| Configuration | Advance authority | Notable topology |
| --- | --- | --- |
| MCP physical control | Agent coordinator | MCP submits ordinary input events and explicitly steps |
| MCP semantic control | Agent coordinator | Tick-addressed game actions avoid pretending to be hardware |
| Reinforcement-learning environment | Agent loop | Action, N ticks, observation/reward/terminal result; many sessions may coexist |
| Branching “what if?” exploration | Fork coordinator | Checkpoint, fork lineages, apply different controls, compare hashes or renders |
| Turn-based play | Accepted-command coordinator | No wall clock; a command requests bounded progress or a typed terminal condition |
| Editor | Editor coordinator | Rebuild, step, checkpoint, scrub through replay, and preview without live mutation races |

### Networking and Distribution

| Configuration | Advance authority | Notable topology |
| --- | --- | --- |
| Headless authoritative server | Server clock or network policy | Network control ingress and replication output; no Render Runtime |
| Deterministic lockstep | Network barrier | Advance only after the next tick's command bundle is complete or timed out |
| Rollback/prediction client | Prediction coordinator | Restore, replay, and distinguish predicted from committed cursor lineages |
| Thin rendering client | Remote snapshot source | Local input and render, but authoritative Simulation lives elsewhere |
| Spectator/replay client | Network or replay timeline | Presentation selects a recorded, observer-following, or free viewpoint without mutating replayed state |
| Cloud streaming | Real-time server driver | Network input, Simulation, offscreen Render, encoder; stale video may drop |
| Distributed offline capture | Job coordinator | Immutable exact snapshots or recorded frames fan out to render workers |

### Replay and Verification

| Configuration | Advance authority | Notable topology |
| --- | --- | --- |
| Deterministic replay | Replay driver | Initial state, seed, tick-addressed input, recorded external results, validation hashes |
| Time-travel debugger | Seek/replay coordinator | Restore a checkpoint and replay the journal to the requested cursor |
| Unit test | Test code | Exact step with no task, sleep, display, or renderer |
| Render golden test | Test coordinator | Reach an exact cursor, offscreen render, compare with controlled tolerances |
| Soak test | Bounded fast driver | Periodic invariant checks and checkpoints; journal enough data to reproduce failure |

### Alternative Presentation

| Configuration | Consumer behavior |
| --- | --- |
| Terminal or teletype | Project positions and content identities into glyphs, ANSI, Braille, sixel, or plain lines |
| Audio-only or narration | Consume continuous audio state plus ordered occurrences; no visual renderer required |
| Accessibility | Speech, haptics, semantic descriptions, or alternate controls consume deliberate surfaces |
| E-ink or LED wall | Present slowly and irregularly; latest-value semantics may be ideal |
| Plotter or printer | Convert one immutable presentation into a finite physical-output job |
| MIDI, OSC, DMX, or haptics | Map continuous snapshots and occurrence events into device-owned commands |
| Telemetry or CSV | Consume a purpose-specific metrics/inspection surface without presentation authority |

The architecture passes the **teletype test** when adding a text backend requires a new consumer projection and perhaps Game Content-supplied glyph rules, but no change to ``World`` ownership, the Simulation schedule, or advancement policy.

The existing presentation snapshot should be used only when it contains the required semantic facts. If a narrator or inspector needs information absent from that contract, Simulation should publish a separately named semantic snapshot rather than turning one presentation value into a universal state bag.

## Configurations May Omit Simulation or Render

The graph must not assume every Runtime is always present.

- a dedicated server can contain Simulation and Network runtimes without Render
- a thin client can render remote presentation snapshots without a local authoritative Simulation Runtime
- an asset preview can construct Render directly from Game Content descriptions
- an input diagnostic can run an Input Runtime without Simulation
- a replay viewer can consume recorded snapshots without reconstructing gameplay
- a batch Simulation can publish only metrics or a final state hash

Optional consumers never become prerequisites for Simulation correctness. Outputs for absent consumers go unobserved.

## Lifecycle and Configuration Switching

The live Runtime Assembly, not the immutable recipe, owns lifecycle. Construction should establish all required connections before any driver can request work.

A safe start sequence is generally:

1. construct and validate all runtimes and adapters
2. establish typed connections and exact request targets
3. start passive providers and consumers
4. start ingress runtimes
5. start the advance authority last

Failure unwinds in reverse order. Shutdown stops the advance authority and new output submissions first. Simulation observes cancellation only between complete ticks. In-flight GPU work is drained or detached while its resources remain retained until actual completion; already submitted GPU work must not be described as canceled when the backend can only await it. Connections are then disconnected and remaining runtimes stop in dependency-safe order.

Switching configurations should initially be a deliberate session transition:

1. suspend the old advance authority
2. drain directed work or request cancellation at supported operation boundaries
3. request a Simulation-owned checkpoint if continuity is required
4. disconnect and stop affected runtimes
5. construct and validate the new assembly
6. restore only deliberate boundary values
7. begin a new identifiable session or lineage

Do not promise arbitrary hot rewiring while world mutation, GPU submission, network replication, or MCP requests are in flight. Attaching a replaceable latest-value observer may be cheap; replacing the advance authority is a coordinated handoff.

## Configuration Validation

An assembly should fail before start with useful diagnostics when:

- a required capability has no provider
- more than one active advance authority targets the same Simulation session without an arbiter
- a directed request/result dependency cycle can deadlock
- an ordered connection has no buffer, overflow, or retention policy
- an offline job has no compatible render target or artifact sink
- a deterministic configuration includes an unrecorded nondeterministic input or asynchronous result
- a surface renderer has no surface, or an offscreen renderer cannot satisfy requested format, size, color space, or quality
- multiple input sources fan in without an explicit merge policy
- an input publication flattens source or channel identity required by a configured recipient route
- an exclusive input lane has more than one active recipient in the same route epoch
- a route transition has no publisher-revision/event-sequence cutover, transient baseline, held-control reacquisition, or stale-epoch rejection policy
- an output binding references an unavailable observer or anchor, or implicitly couples a Render viewpoint to an Audio listener
- a connection crosses an isolation, process, or transport boundary with values that cannot safely cross it
- restored input baselines can leave held controls stuck across publication sessions
- output and Simulation rates require interpolation but no interpolation or sampling policy exists

Validation is not a global registry. It inspects the concrete, explicitly owned assembly being constructed.

## Determinism and Concurrency

Separating pacing makes the deterministic boundary clearer:

```text
initial world + fixed step + invariant schedule + seed + tick-addressed controls
                              |
                              v
                    completed Simulation state
```

Wall-clock speed, GPU duration, and Codex thinking time determine when requests arrive, not the result of a tick.

A Runtime boundary is a semantic ownership and lifecycle boundary, not a promise of one actor, executor, thread, or pool. Each Runtime owns a concurrency policy that keeps its private mutable state inside its boundary. Cross-runtime work uses immutable `Sendable` values and explicit publication or request/result capabilities.

The App may construct assemblies, expose UI-observable lifecycle state, and perform framework-required view work on `MainActor`. That does not require potentially long-running Simulation ticks, Render preparation and encoding, or other Runtime CPU work whose cadence must remain independent to execute there. The current shared main-actor placement is a transitional implementation constraint, not a requirement for new Runtime capabilities.

Each authoritative Simulation session requires one serialized world-mutation domain. A complete tick executes synchronously within that domain, cannot `await`, and cannot overlap another tick for the same session. Runtimes whose cadences should remain independent must not place long-running work on the same required serial isolation domain merely because the App wires them together. Multiple Runtime instances and Simulation sessions may still share bounded execution capacity.

The mechanism remains deliberately open. Swift actors, custom executors, bounded worker pools, helper processes, or other designs can satisfy the contract. A Runtime Configuration may choose an implementation or process placement; it should not expose raw thread management as Runtime topology.

This direction requires:

- immutable boundary values that explicitly conform to `Sendable`
- serialization or `Codable` contracts where values cross processes
- explicit ordering when ingress arrives from several concurrency domains
- one serialized mutation domain for each authoritative Simulation session
- no `await` inside the mutation of one tick
- bounded batches so one session cannot monopolize shared execution capacity
- cancellation between ticks, never during partial world mutation
- GPU completion and encoding state remain owned by Render/Capture and cross Runtime boundaries only through immutable results

Configuration alone does not guarantee bitwise replay across hardware. Stable system ordering, seeded randomness, recorded external results, content/version fingerprints, and disciplined floating-point behavior remain separate requirements.

## Game Content Remains Orthogonal

One `BasicGameContent` value can feed several configurations:

- its world builder configures Simulation in real-time, offline, MCP, test, or server assemblies
- its render catalog configures screen, offscreen, thumbnail, or alternate render consumers
- future text, audio, or accessibility presentation mappings configure the runtime that performs those projections

Game Content does not select cadence, start runtimes, own caches, or coordinate requests. The App supplies the relevant portions to the runtimes chosen by the Runtime Configuration.

## Current Implementation Mapping

| Current element | Relevance to the proposed model |
| --- | --- |
| ``Engine/step(inputSnapshot:)`` | Existing exact one-step execution seam; remains private to Simulation implementation and focused Engine tests rather than becoming the configuration boundary |
| ``Engine/update(deltaTime:inputSnapshot:)`` | Current real-time remainder and catch-up policy; candidate to move behind the real-time driver |
| ``SimulationLoop`` | Current wall-clock cadence adapter; candidate to become configuration/App-owned rather than Simulation-owned |
| ``SimulationRuntime`` | Correct owner of session construction, authoritative state, step serialization, and completed publications; currently hard-wires the real-time driver |
| ``InputRuntime`` | Implemented single-channel physical-input authority with narrow ingress and latest-snapshot capabilities; multi-source and multi-seat fan-in still need source/channel identity, source-local state, and configured merge policy |
| ``InputState`` | Existing Simulation-local consumer cursor and cumulative baseline; evidence that importing a snapshot need not consume it for another recipient |
| `World.camera` and ``SCameraInput`` | Current single Simulation-owned orbit camera; useful implementation evidence but too coupled for frozen photo mode and independent output viewpoints |
| ``SimulationPresentationSnapshot`` | Existing immutable publisher-owned presentation surface with one Simulation-published camera that can become a default rather than the only permitted viewpoint |
| `PSimulationPresentationSource` | Existing latest-value live boundary, suitable for droppable consumers |
| ``RenderFrame`` | Existing Render-owned private projection with source-tick attribution and an implicit source camera; candidate to accept an explicitly resolved viewpoint |
| `MetalRenderer` and `MetalSceneView` | Current screen-oriented rendering path; view ownership and drawable cadence still need extraction for a full Render Runtime |
| Render integration test support | Evidence that explicit offscreen textures and GPU submission are practical, though production artifact readback/encoding remains absent |

The most important current gaps are:

- ``SimulationRuntime`` always constructs a concrete ``SimulationLoop``
- the Runtime retains one input source instead of receiving explicit tick-boundary control through an advance request
- Input Runtime has no source identity, source-local held state, or merge policy for simultaneous hardware, MCP, network, and bot ingress
- there are no typed Input Routes, route epochs, per-recipient connection baselines, or explicit exclusive/shared delivery policies
- direct ``Engine/step(inputSnapshot:)`` does not automatically update Runtime publications according to their declared semantics
- `SimulationRuntime.engine` is internally visible and `SimulationRuntime.world` exposes the live mutable world; current App tooling such as input-history and entity-motion panes uses that escape instead of deliberate inspection capabilities
- `start`, `stop`, `resumeSimulation`, and `pauseSimulation` combine lifecycle, driver, and schedule-gating concerns
- the always-versus-gated Engine schedule exists largely to keep camera and tool/input state responsive while gameplay systems are paused, so the same tick identity currently describes partial and complete schedules
- output-specific orbit and zoom currently enter Simulation-owned `InputState`; the singular `World.camera`, snapshot, and ``RenderFrame`` cannot represent several observer anchors, independent Render/Audio bindings, or viewpoint changes attributed separately from cursor changes
- there is no recorded presentation-viewpoint lane for reproducing an exact player camera independently from replayed Simulation state
- ``Engine/update(deltaTime:inputSnapshot:)`` contains unbounded real-time catch-up policy
- latest presentation publication can skip intermediate ticks and cannot guarantee an exact offline/MCP result by itself
- ``SimulationTick`` is not qualified by a Simulation session identity
- concrete configuration builders, concrete assembly types, and host selection remain proposed
- there is no production view-independent `RenderRuntime`, offscreen request API, image artifact contract, or JPEG encoder
- there is no Audio Runtime, immutable listener-description contract, listener resolver, or Audio output-binding implementation; Audio examples in this article are directional
- ordered Simulation events, input transitions, checkpoints, and journals remain proposed
- the project currently defaults unannotated code to `MainActor`, while existing Input, Simulation, presentation-source, and Metal boundaries reinforce that placement; migration requires deliberate isolation and `Sendable` work rather than deleting one outer annotation

None of these gaps require weakening ECS authority or introducing backend objects into ``World``.

The first CPU-isolation evidence is tracked in [GitHub issue #16, *Define executor isolation between Simulation and Render CPU work*](https://github.com/twistinside/engine2/issues/16). It asks the implementation to prove independent Simulation and Render CPU progress while preserving required UI and view isolation; this article intentionally leaves the actor, executor, pooling, and process strategy open.

## Incremental Implementation Path

### 1. Establish Session-Qualified Identity

Add a Simulation session/epoch identity and pair it with ``SimulationTick``. Propagate the cursor through presentation snapshots, render attribution, advance results, and eventually events and artifacts.

### 2. Add a Runtime-Level Exact Advance Capability

Make ``SimulationRuntime`` the only application/configuration integration boundary that calls ``Engine/step(inputSnapshot:)``. Direct calls remain valid inside Simulation implementation and focused ``Engine`` unit tests. For the physical-input slice, the active Simulation Input Route captures a consumer-specific snapshot/baseline assignment and the advance driver submits it as part of the same non-interleavable Runtime request. The Runtime validates and applies that assignment at the tick boundary, completes full ticks, updates snapshots and events according to each lane's declared semantics, and returns an exact correlated result.

Replace App-tooling access to the live `world` with deliberate read or inspection snapshots before making the Runtime boundary inaccessible. UI and MCP inspection must not become alternate mutation paths.

### 3. Extract the Realtime Driver Without Changing Behavior

Move ``SimulationLoop`` ownership into the App's first concrete Runtime Assembly. Move elapsed-time remainder, catch-up cap, and overload policy out of the deterministic Simulation core. Rebuild today's app as `RealtimeConfiguration` and prove parity with existing tests.

### 4. Separate Viewpoint Control and Make Pause an Advancement Policy

Move output-specific orbit and zoom control out of the partial Simulation schedule and into a per-view or App-owned presentation controller. Allow Render to combine an unchanged Simulation presentation value with an explicit viewpoint while retaining the current Simulation camera as a default during migration.

Introduce the distinction between Simulation observer identity, Simulation-authored presentation anchors, and modality-specific output bindings. Preserve the current camera as the first default anchor/viewpoint path, then prove with Render that one completed Simulation value can expose several anchors and that output bindings remain outside ``World``. Specify the same one-way anchor and binding contract for future Audio without making an Audio implementation a prerequisite for this slice.

Once paused camera behavior has an independent path, stop issuing Simulation ticks during ordinary pause. Retire `isSimulationRunning` and the always-versus-gated list split as the production pause mechanism. Simulation-facing input import, cleanup, and export remain invariant stages of every complete tick; genuinely authoritative camera rigs remain ordinary members of that complete schedule.

### 5. Prove a Manual Configuration

Add a tiny deterministic assembly that can advance exactly one or N ticks without a polling task. This is the cheapest proof that Simulation is no longer tied to real time and is a foundation for tests, replay, offline work, and MCP.

### 6. Add Multi-Source Input and Typed Routing

Give Input Runtime source and channel identities, source-local state, deterministic acceptance ordering, detach neutralization, and explicit merge policy. Add App-owned typed Input Routes with independent consumer baselines, route epochs, and exclusive/shared delivery policy. Prove concurrent adapters at the edge, non-destructive fan-out, and safe context rebasing while keeping canonical mutation and publication serialized at the Runtime boundary.

### 7. Create a View-Independent Render Runtime Boundary

Separate render resource ownership and explicit-frame encoding from `MTKViewDelegate` and SwiftUI view lifetime. Preserve the existing view adapter for screen presentation.

### 8. Add Production Offscreen Request/Result Rendering

Accept an exact immutable presentation value plus an explicit viewpoint and target/quality settings, await GPU completion, read back, encode, and return an artifact labeled with its Simulation cursor, viewpoint identity, and settings identity. Reuse current backend passes where practical.

### 9. Add Offline Render-Gated Coordination

Map an output timeline to exact Simulation cursors, render one or more outputs per cursor, and apply the configuration's declared serial or bounded-pipeline backpressure policy.

### 10. Add MCP Coordination

Start with physical input emulation if useful, then add semantic control deliberately. Serialize commands, enforce expected cursors and idempotency, bound steps, expose structured observations, and return exact image artifacts.

### 11. Add History Only for Concrete Needs

Introduce event lanes, checkpoints, journals, rollback, and time travel when their configurations require them. Do not burden ordinary latest-value real-time connections with durable history by default.

## Verification Required During Migration

Tests for this direction should prove:

- a Runtime-level manual step advances exactly once and publishes/returns the exact completed cursor
- no application/configuration path can mutate the Engine while bypassing Runtime publication invariants; focused Engine tests remain valid
- extracted real-time driving preserves current fixed-step and input behavior
- ordinary pause causes no Simulation cursor change
- a presentation viewpoint can change and trigger another render while the source Simulation cursor remains unchanged
- one exact Simulation presentation value can render from several independently identified viewpoints
- entering and leaving photo mode establishes new route epochs, does not replay accumulated physical input, and applies the declared held-control policy
- no production advancement path allows an external caller to select a partial Simulation system schedule
- full-tick input import, cleanup, system ordering, publication, and cursor advancement remain invariant across every advance authority
- each routed recipient derives cumulative transients at most once relative to its own cursor, and no recipient advances another recipient's cursor
- shared recipients may skip or accept revisions independently; one recipient's sampling decisions do not mutate the publication, advance another recipient's cursor, or alter the total motion that the other recipient derives from its own baseline
- every route transition has an exact publisher-revision/event-sequence cutover and rejects delivery from stale route epochs
- Simulation advance input attribution preserves publisher, channel, route epoch, recipient, and baseline scope
- exclusive photo-mode and replay free-view routes cannot also steer authoritative gameplay
- two input sources holding the same control do not cancel one another when either source releases or disconnects
- one Simulation session can publish distinct anchors for several observer identities at one cursor
- Render and Audio outputs bind independently to observer anchors or presentation overrides without mutating Simulation or changing gameplay perception
- Render consumes a resolved viewpoint rather than raw Input Runtime state
- replay can switch among recorded, observer-following, and free viewpoints without changing its Simulation cursor; route changes apply held-control and stale-epoch policy, while Audio remains on its explicitly selected listener binding
- a world rebuild produces a new session-qualified cursor
- stale expected-cursor and duplicate MCP requests cannot double-advance
- cancellation reports only fully completed ticks
- offline Render receives the exact requested immutable snapshot even if rendering is slow
- configuration startup, partial failure, and reverse-order shutdown are deterministic
- realtime and manual builders construct complete assemblies with exactly one effective advance authority per Simulation session
- multiple assemblies have no global mutable-state contamination
- two seeded Simulation Runtime instances advance, publish, stop, and rebuild without shared mutable state or cursor contamination
- in a configuration whose policy permits independent progress, long-running Simulation CPU work does not prevent Render-side CPU progress, and slow Render preparation does not stop completed Simulation ticks
- offscreen artifacts preserve Simulation cursor, viewpoint identity or revision, render settings, and content identity needed for attribution
- each event or publication connection obeys its declared backpressure and retention policy

## Architectural Traps

Avoid:

- creating a `TickRuntime` that owns Simulation's fixed delta or tick counter
- using an ECS `S` type for top-level cadence or configuration work
- letting a Render Runtime, MCP Runtime, Network Runtime, or view call ``Engine`` or mutate ``World``
- exposing elapsed `deltaTime` as the only portable advancement API
- allowing several drivers to race and relying on actor serialization to make the order meaningful
- using a camera-only, tooling-only, or caller-selected system bucket as a second meaning of Simulation tick
- assuming one render frame equals one simulation tick
- requiring every render of a Simulation presentation value to use one embedded default camera
- treating a Simulation observer anchor as inherently one Render camera, Audio listener, window, or stream
- assuming one observer identity has exactly one presentation anchor or exactly one output
- feeding Render culling, a resolved camera, or Audio mixing results back into AI or gameplay perception
- allowing Render or Audio to consume and interpret raw input state
- using one destructive input cursor or baseline for several recipients
- implicitly rebinding Audio whenever a render viewpoint changes
- advancing the Simulation cursor merely to move an output-specific viewpoint
- allowing presentation input accumulated while paused to replay as gameplay input on resume
- using a replaceable latest slot for an exact offline or MCP result
- losing intermediate events silently during a multi-tick request
- identifying state by a resettable bare tick
- turning configurations into a global service locator, event bus, or mutable runtime registry
- encoding the graph in `Any`, strings, or a bag of optionals
- forcing device input, network commands, replay records, and semantic MCP actions into one lowest-common-denominator schema
- turning ``SimulationPresentationSnapshot`` into an exhaustive mirror of ``World``
- treating an event as a command or an ordinary event stream as a durable journal
- allowing render sampling quality to change Simulation's fixed step implicitly
- allowing a slow optional consumer to block real-time Simulation accidentally
- retaining unbounded history for every configuration
- hot-swapping advance authority while work is in flight
- creating a Runtime for every stateless adapter or formatter
- treating independent Simulation sessions as adapters inside one mutable World-owning Runtime
- equating one Runtime with exactly one actor, executor, operating-system thread, or private thread pool
- executing potentially long-running Runtime CPU work on `MainActor` merely because App composition begins there
- putting JPEG, terminal, network, or Metal backend concerns into ECS state
- assuming every valid assembly contains both Simulation and Render

## Durable Invariants

Future configuration work should preserve these rules:

1. The Simulation Runtime is the sole owner of authoritative world mutation.
2. Exactly one complete Simulation tick executes at a time per session.
3. At most one effective advance authority is active per Simulation session; exactly one authority or arbiter exists whenever progress is permitted.
4. Simulation owns fixed-step meaning, schedule, cursor, and completed publications; external policy owns when progress is requested.
5. Wall time, display time, output media time, network time, and simulation time remain distinct.
6. Input and semantic control enter authoritative Simulation state only at safe, attributable tick boundaries.
7. Reset, rebuild, restore, and fork produce unambiguous session or lineage identity.
8. Exact workflows receive exact immutable values; latest-value consumers may skip superseded values.
9. Snapshots, events, commands, results, and journals keep distinct semantics.
10. Optional consumers do not change Simulation correctness.
11. Consumers own their projections, backend state, quality settings, caches, encoding, and physical I/O.
12. Backpressure and retention policy are explicit per connection.
13. Cancellation is observed only between ticks or supported output operations; recoverable failures do not expose partially mutated Simulation as a valid cursor and report the last committed cursor or completed artifact state.
14. Runtime topology is explicit at the App composition root and never globally discoverable mutable state.
15. Multiple complete assemblies can coexist without contaminating one another.
16. A Simulation cursor advances only after the complete invariant schedule has been evaluated; configurations do not select partial system subsets.
17. Output-specific viewpoints may change independently of Simulation state, and exact render results identify both their scene source and viewpoint.
18. Each Runtime owns the concurrency policy for its private mutable state; cross-runtime mutable implementation state never escapes its boundary.
19. Runtime ownership does not require a dedicated actor, executor, thread, or pool, but independently advancing Runtimes must not be forced through one required serial execution domain.
20. Input Runtime owns source facts, the Runtime Assembly owns routes, and recipients own interpretation; no recipient destructively consumes another recipient's input.
21. Input source, logical input channel, player or observer, window or viewport, output, viewpoint, and Simulation-session identities are explicit and are never inferred to be one-to-one.
22. Simulation-authored observer anchors are one-way completed publications; Render viewpoints, Audio listeners, and other modality-specific values are resolved through explicit output bindings.
23. Presentation input and output-specific state cannot feed back into Simulation except through a deliberate Simulation-owned command accepted at a tick boundary.

## Open Design Questions

The following details should remain open until the first vertical slices provide evidence:

- the exact names and sync/async shape of the Simulation advance protocol
- whether every one-step result directly carries the presentation snapshot or uses an exact cursor-addressed rendezvous
- the optimized representation of per-tick input/control batches
- the first typed input-publisher, Input Route, input-channel, route-epoch, cutover, and independent consumer-baseline contracts
- how long exact snapshots are retained for render retries and remote requests
- whether the real-time driver is an ordinary App-owned coordinator or earns a Runtime boundary
- the exact immutable viewpoint boundary and how a Simulation-published default camera or anchor composes with consumer-supplied viewpoints
- the observer and presentation-anchor identity types, including whether one observer may publish several Game Content-defined anchor roles
- whether observer-scoped visibility is represented by filtered presentation snapshots, typed visibility facts, or another deliberate publication surface
- the first typed output-binding representation for screens, offscreen jobs, audio mixes, and remote streams
- which presentation facts must be journaled to reproduce an exact recorded player view rather than merely follow a replayed observer anchor
- whether an interactive screen assembly retains an ordinary viewpoint controller or eventually justifies a dedicated Runtime
- how Runtime internals migrate away from the project-wide `MainActor` default while preserving App, UI, and framework-required isolation
- which Runtime implementations require distinct isolation domains and which may share bounded execution capacity
- whether concrete isolation uses actors, custom executors, another in-process mechanism, helper processes, or a combination
- which Render preparation and encoding work can leave view-facing isolation
- the first structured agent-observation contract
- production image artifact ownership, formats, metadata, and persistence
- interpolation contracts for offline temporal sampling and high-refresh display presentation
- configuration diagnostics and whether a reusable assembly type is valuable before several concrete configurations exist

These mechanics should be selected incrementally without compromising the ownership and cadence separation defined here.

## Related Direction

- <doc:Runtime-Architecture>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
- <doc:Engine-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
- <doc:Rendering-Architecture>
- <doc:System-Scheduling>
