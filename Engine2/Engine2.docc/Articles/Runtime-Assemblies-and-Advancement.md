# Runtime Assemblies and Advancement

This article defines the real-time Runtime Assembly and the advancement rules that keep Simulation authoritative. It also records general constraints for future topologies without presenting them as current release architecture.

## Status

Partially implemented direction.

The current release implements the shared exact-advancement foundation and one ``RealtimeAssembly``. ``SimulationSessionID`` and ``SimulationCursor`` qualify resettable tick values and propagate through ``SimulationPresentationSnapshot`` and ``RenderFrame``. ``SimulationRuntime`` requires one validated ``SimulationConfiguration``, exposes the exact ``SimulationAdvanceTarget`` request/result capability, applies immutable input assignments at the tick boundary, and owns no wall-clock loop or live Input source.

``RealtimeAssembly`` constructs and owns ``RealtimeAdvanceDriver``. The driver owns wall-clock sampling, elapsed remainder, pause policy, immutable input capture, exact requests, bounded catch-up with explicit overflow treatment, and async stop-and-drain while Simulation owns execution. Assembly lifecycle generations prevent stale asynchronous completion from applying an older visibility decision.

``RealtimeAssemblyView`` hosts `MetalScenePlatformView` as the single `MTKView` used by `MetalRenderer` and as a thin AppKit ingress adapter. ``InputRuntime`` maps physical events into semantic intent. Simulation applies camera and gameplay input only during complete ticks, and `MetalRenderer` uses the camera in the latest completed ``SimulationPresentationSnapshot`` exactly. ``MetalFrameEncoder`` keeps reusable Metal frame preparation independent from MetalKit surface acquisition and screen submission policy.

``RuntimeAssembly`` is the common App-hosting boundary. It refines SwiftUI `View`, requires `init(using:)`, and lets each concrete assembly own its topology-specific presentation lifecycle in `body`. `Engine2App` injects Mining Game Content into its compile-time-selected ``RealtimeAssembly`` and renders that value directly.

Offscreen rendering, snapshot export, replay, and agent control are outside the current release. Future topologies must preserve the same separation between pacing, coordination, exact-result delivery, and Simulation execution.

## The Architectural Thesis

Engine2 applications should be explicit assemblies of independently owned runtimes. The selected concrete assembly determines which runtimes exist, how their typed boundaries connect, and which focused policy decides when Simulation may advance.

The decisive separation is:

> An assembly-selected **advance authority** decides when and how much progress to request. The Simulation Runtime remains the only owner of what a simulation tick means and the only Runtime permitted to execute one.

The Simulation Runtime continues to own:

- ``World`` and authoritative ECS mutation
- ``Engine`` and the invariant system schedule
- the fixed duration represented by one simulation tick
- serialized, atomic execution of each complete tick
- simulation session and tick identity
- publication of completed Simulation-owned snapshots and events

The active advance authority owns or selects:

- whether requests follow wall time, a future network barrier, or a deterministic test
- how many exact ticks to request
- real-time remainder, catch-up, overload, rate, and pause policy
- how input or semantic control is assigned to tick boundaries
- when a directed workflow should inspect, persist, or return a result before requesting more progress

This preserves Simulation authority while allowing its cadence to be completely replaceable.

## Vocabulary

### Runtime Assembly

A **Runtime Assembly** is one live, explicit runtime topology. The App constructs Game Content and passes it to the assembly's required initializer. The App selects one concrete assembly type at compile time and retains it behind an opaque `some RuntimeAssembly` property. The hidden type remains fixed and available to the compiler without exposing topology-specific capabilities to the window. The assembly remains an explicit transitive ownership mechanism rather than a new globally discoverable runtime. Depending on its topology, it owns or exposes:

- the runtime instances
- adapters and coordinators whose lifetimes are not private implementation details of one retained Runtime
- typed input routes, output bindings, and their active epochs or subscriptions
- connection tasks, subscriptions, and cancellation tokens
- at most one active advance authority for each Simulation Runtime
- lifecycle ordering and failure unwinding
- the topology-specific root UI through its inherited View body; SwiftUI owns local `@State`, while the assembly retains shared UI models and operational dependencies

The common ``RuntimeAssembly`` boundary refines SwiftUI `View` and requires `init(using:)`. The initializer lets each concrete type build its graph from App-selected content. `View` supplies the associated `Body` type and `body` requirement, so a conforming assembly can implement `var body: some View`. That body owns any SwiftUI appearance modifiers required by its topology, and the opaque result resolves to one concrete body type for that conformer.

Concrete assemblies are structures because SwiftUI requires custom views to use value semantics. Each assembly value strongly retains its Runtime, driver, and focused mutable-state references. SwiftUI copies therefore remain handles to one live graph; only an initializer constructs a new graph. ``RealtimeAssemblyLifecycleState`` shares transition identity across those copies.

`Engine2App` uses a different opaque type at its storage boundary. Its `some RuntimeAssembly` property preserves one hidden concrete assembly type selected by the property's initializer, so SwiftUI can render the stored value directly. This is compile-time selection, not a runtime box for arbitrary conformers. Runtime-dynamic heterogeneous selection would require an explicit enum or a deliberate type-erasing host. The protocol is not a container of optional Runtime services or a topology-specific terminal-shutdown contract.

### Runtime Adapters, Sources, and Workers

An **Adapter** translates an external mechanism into one narrow runtime-owned ingress or translates a runtime-owned value into an external mechanism. A keyboard adapter, game-controller adapter, and future network-control adapter can feed the Input Runtime without becoming part of its authoritative state.

Adapter lifetime is contextual. An Input Runtime may retain device readers that are intrinsic to its implementation, a view may retain its platform-event adapter, and an assembly may retain a connector between two peer capabilities. Whichever owner constructs an adapter must also make its cancellation and disconnection path explicit.

The reusable principle is **parallel at the edge, serialized at the authority**. Adapters may wait for devices or transport messages concurrently, but the owning Runtime assigns source identity, orders accepted changes, and publishes one coherent boundary value. An adapter must never mutate another Runtime's state directly.

The pattern generalizes, but the roles should keep contextual names rather than conforming to one universal `RuntimeAdapter` abstraction:

- Input has ingress sources that fan into one input authority.
- Render has output targets or workers that fan immutable work out to one or more backends.
- Network has connections or peers with transport-specific lifecycle.
- Storage has providers or sinks with persistence-specific failure semantics.
- Batch orchestration owns multiple complete Runtime instances rather than disguising independent authorities as adapters inside one Runtime.

These roles share explicit ownership and typed boundaries, not necessarily one lifecycle, direction, concurrency model, or protocol.

### Advance Authority

An **Advance Authority** is the effective authority allowed to decide when a particular Simulation Runtime progresses. A frozen or render-only assembly may have no active authority; whenever progress is permitted, exactly one authority or arbiter must be active.

It is a role, not necessarily one universal type. A real-time driver, a future network lockstep coordinator, or a deterministic test harness can each fill the role. Multiple request sources are valid only when an explicit arbiter serializes them and becomes the effective authority.

### Advance Driver and Coordinator

An **Advance Driver** translates one cadence source into Simulation advance requests. A real-time driver, for example, converts monotonic elapsed time into an exact number of fixed ticks.

A **Coordinator** deliberately sequences request/result operations across several narrow runtime capabilities. For example, a save coordinator could request a checkpoint and ask a Storage Runtime to persist it.

Not every small driver or coordinator earns a Runtime boundary. A network service with transport state, request lifetime, and an independent lifecycle may earn a Runtime boundary; a small deterministic test driver remains an ordinary helper. The existing Runtime criteria still apply.

### Simulation Cursor

A **Simulation Cursor** identifies one committed logical position within a continuous Simulation session: a ``SimulationSessionID`` paired with a ``SimulationTick``.

A bare tick is insufficient because rebuilding or replacing a world currently resets the tick to zero. Delayed results and comparisons across sessions need an unambiguous identity.

Every discontinuity that can make the same tick number describe different state must establish a new Simulation session identity. This includes rebuilding, restoring, rewinding, and forking, even when the same ``SimulationRuntime`` object remains alive. If future rollback distinguishes predicted, corrected, and committed histories more richly, the cursor may grow explicit lineage or epoch identity rather than weakening this rule.

## An Assembly Selects Topology and Policy

An assembly selects independent topology and policy axes:

| Axis | Representative choices |
| --- | --- |
| Session source | New world, generated scenario, checkpoint, forked checkpoint |
| Control ingress | Keyboard, controller, pointer, network, script, none |
| Control vocabulary | Physical device state, mapped player actions, game-semantic commands |
| Control routing | Input-channel assignment, exclusive recipient, deliberate fan-out, partitioned binding, focus and route-epoch policy |
| Advance authority | Wall clock, network barrier, test, fastest possible |
| Progress request | Exact tick, bounded tick batch, target cursor, finite job horizon |
| Output surface | Presentation, audio, network replication, inspection, metrics, state hash, checkpoint |
| Presentation backend | Onscreen Metal, text, audio-only, physical device, none |
| Delivery semantics | Latest replaceable, exact request/result, ordered buffered, durable journal |
| Cardinality | One Simulation with many consumers, many isolated Simulations, client/server or validation pairs, render-only assembly |
| Lifetime | Continuous application, finite job, request-driven session, one-shot test |
| Backpressure | Drop, coalesce, bound, block the next request, persist |
| Determinism | Best-effort live, recorded external inputs, reproducible exact-step session |
| Execution placement | Framework-required actor, Runtime-owned in-process isolation, helper process, remote transport |

A Runtime boundary is not necessarily a one-to-one mapping to an actor, executor, thread, or thread pool. An assembly may select an implementation or operational placement, while each Runtime remains responsible for the isolation and scheduling of its private mutable state.

These choices must not be accidentally fused:

- onscreen rendering does not imply real-time Simulation
- headless operation does not imply maximum-speed advancement
- a display callback does not imply one render frame per simulation tick
- high render quality does not imply a smaller or variable simulation step

Concrete assembly initializers and focused domain values are preferable to a universal runtime-graph DSL. Avoid wrappers that only forward into an assembly, a mutable dictionary of services, `Any`-typed ports, string-selected runtime classes, or one structure full of optional runtimes and Boolean mode flags. Those approaches add indirection or hide invalid assemblies until execution.

### Concrete Assembly Shape

Each materially different topology has a concrete live assembly with its own production construction and root UI. ``RuntimeAssembly`` provides only the common App-hosting boundary:

```swift
protocol RuntimeAssembly: View {
    init(using content: any GameContent)
}

@main
struct Engine2App: App {
    private let assembly: some RuntimeAssembly = RealtimeAssembly(
        using: MiningGameContent()
    )

    var body: some Scene {
        Window("Engine2", id: "main") {
            assembly
        }
    }
}
```

`Engine2App` selects one Game Content value and one concrete assembly type, then injects the content through the common initializer. The opaque property hides the assembly type from the surrounding App surface while preserving it for the compiler and SwiftUI. Its underlying type is fixed by the initializer; changing the selected topology is a source-level choice. Runtime-dynamic selection among different assembly types would require an explicit enum or type-erasing host rather than a conditional initializer for this opaque property.

Each concrete assembly owns the required Game Content initializer and may expose a topology-specific initializer for focused policy or other validated domain values that topology needs. The current ``RealtimeAssembly`` direct initializer accepts a polling interval and ``RealtimeCatchUpPolicy`` in addition to Game Content. No separate forwarding-wrapper or assembly-factory layer remains.

Three decisions remain separate:

1. **Topology** is expressed by the concrete assembly type.
2. **Parameters** such as seed, endpoint, resolution, or output path are strongly typed in an assembly's defaults or explicit initializer.
3. **Selection** happens at the outer App or executable boundary by choosing a concrete assembly type.

A finite App catalog that selects among concrete assembly types at runtime needs a host-owned enum or deliberate type eraser. The opaque App property itself cannot switch its underlying assembly type. Tests can construct a concrete assembly directly when they need nonproduction content or policy. Launch arguments or a configuration file can populate those direct initializer values at process start through that explicit dynamic-selection boundary. A development UI can stop one assembly and construct another through the coordinated transition described below. Materially different deployment and entitlement needs may justify separate executables that select different assemblies at compile time. App targets, command-line flags, and in-app modes remain selection mechanisms around the same typed composition model; they are not topology objects themselves.

Engine consumers must be able to define their own concrete assemblies without extending a closed Engine2-wide enum.


### Cardinality Belongs to the Assembly

The default ownership unit is one authoritative Simulation session per ``SimulationRuntime``. A Monte Carlo, reinforcement-learning, validation, or branching assembly creates several isolated Simulation Runtime instances and lets its batch coordinator schedule them. This keeps each World, cursor, request gate, publication set, and failure boundary unambiguous.

A future `SimulationHostRuntime` or session pool may earn a boundary when shared worker management creates concrete lifecycle or scheduling value. It should still expose session-qualified capabilities and preserve per-session isolation. Different seeds are not adapters inside one mutable Simulation Runtime, and a single Runtime should not silently multiplex independent Worlds merely because they execute similar code.

Assemblies select among declared typed capabilities and may choose per-connection buffering, retention, and backpressure policy where the publisher's contract permits it. They do not redefine publisher-owned vocabulary or reinterpret a latest-value source as an exact result or durable journal.

## Advancement Is a Directed Boundary

Snapshots and events are consumer-agnostic publications. Advancing Simulation is different: it is a deliberate command with a correlated result.

The Simulation Runtime exposes a narrow, Simulation-owned advance capability. Its current API has this semantic shape:

```swift
nonisolated struct SimulationSessionID:
    Codable, Hashable, RawRepresentable, Sendable
{
    let rawValue: UUID
}

nonisolated struct SimulationCursor: Codable, Hashable, Sendable {
    let sessionID: SimulationSessionID
    let tick: SimulationTick
}

nonisolated struct SimulationStepCount:
    Hashable, RawRepresentable, Sendable
{
    // Construction validates that rawValue is greater than zero.
    let rawValue: UInt32
}

nonisolated struct SimulationCompletedStepCount:
    Hashable, RawRepresentable, Sendable
{
    // Current completed results are positive. Zero is reserved for a future
    // interrupted outcome that commits no requested work.
    let rawValue: UInt32
}

nonisolated enum SimulationInputAssignment: Sendable {
    case none
    case ingest(InputSnapshot)
    case rebase(InputSnapshot)
    case rebaseThenIngest(
        baseline: InputSnapshot,
        snapshot: InputSnapshot
    )
}

nonisolated struct SimulationAdvanceRequest: Sendable {
    let expectedCursor: SimulationCursor?
    let stepCount: SimulationStepCount
    let inputAssignment: SimulationInputAssignment
    let orbitCircularizationCommand: OrbitCircularizationCommand?
}

nonisolated struct SimulationAdvanceResult: Sendable {
    let initialCursor: SimulationCursor
    let finalCursor: SimulationCursor
    let completedStepCount: SimulationCompletedStepCount
    let finalPresentationSnapshot: SimulationPresentationSnapshot
}

nonisolated enum SimulationAdvanceOutcome: Sendable {
    case completed(SimulationAdvanceResult)
    case rejected(SimulationAdvanceRejection)
}

nonisolated protocol SimulationAdvanceTarget: AnyObject, Sendable {
    func advance(_ request: SimulationAdvanceRequest) async -> SimulationAdvanceOutcome
}
```

These boundary values and their complete presentation-snapshot value graph are explicitly `nonisolated` and `Sendable`, so they do not inherit the app target's current default `MainActor` isolation. ``SimulationRuntime`` is currently `MainActor`-isolated by that target default and provides a nonisolated asynchronous protocol witness that enters its serialized mutation domain. A future implementation may use its own actor or another concurrency-safe placement without changing the capability. Neither `async`, `Sendable`, nor actor isolation by itself establishes the request-ordering rules below.

The current semantic-input slice carries one immutable ``SimulationInputAssignment`` with each request. `.ingest` derives current camera and selection transients against Simulation's private baseline, `.rebase` establishes a new baseline without replaying cumulative semantic commands, and `.none` advances without a new semantic input value. The exact boundary also accepts `.rebaseThenIngest(baseline:snapshot:)`: after cursor validation, Simulation atomically installs the captured transition baseline and ingests a later publication at the first requested tick, so only same-session transients accumulated after that baseline survive. ``RealtimeAdvanceDriver`` samples its configured latest-value source once and submits a captured assignment with the exact request; ``SimulationRuntime`` does not retain the source.

The same exact request may carry one optional ``OrbitCircularizationCommand``. ``SelectedEntityInspector`` supplies the displayed full ``EntityID`` through a focused callback, ``RealtimeAssemblyViewModel`` routes it through ``RealtimeAssembly``, and ``RealtimeAdvanceDriver`` stages it behind a private generation. The next cursor-qualified request captures that generation's command. A completed request retires only the generation it carried, so a newer click received in flight remains pending; session synchronization clears commands from the older session. This directed gameplay command does not pass through ``InputRuntime``.

``RealtimeAdvanceDriver`` uses that transition form today. It captures the latest publication immediately when an enabled connection starts or resumes, or when ``RealtimeAssembly`` synchronizes a rebuilt session. At the later request boundary it samples the current publication and carries both immutable values together, preserving same-session input accumulated between activation and the first subsequent tick without replaying inactive history. Publisher identity, channel identity, route epochs, recipient identity, and full typed Input Route validation remain proposed.

Replay, networking, bots, or Game Content may later require tick-addressed semantic control batches. Those should use a Simulation-owned typed control surface or a deliberate evolution of the request rather than making keyboard-shaped state the permanent command vocabulary. Whatever the selected ingress, the controls consumed by a tick must be attributable to its advance request.

For a multi-step request carrying one semantic snapshot assignment, the baseline policy imports that snapshot before the first requested tick. Simulation derives interval-local camera and selection commands once for the first tick, while held translation and interaction intent remain available to later ticks. An assigned orbit command is likewise visible only to that first tick and is then cleared. A future route could make the same immutable snapshot available to other recipients with independent baselines. A batch that changes controls between ticks requires an explicit tick-addressed schedule. Exact results or an accompanying journal should eventually identify the input publisher, channel, route epoch, revision, or semantic-control identities consumed by the committed cursor range.

`SimulationStepCount` is strictly positive. Reading completed state without advancing is a separate capability rather than a zero-step command with hidden side effects.

The required advancement semantics are more important than the illustrative API:

- a request asks for an exact, strongly typed number of fixed steps rather than supplying an arbitrary floating-point delta
- Simulation validates the expected cursor when one is supplied
- only one tick mutates the world at a time
- one tick cannot suspend halfway through its system schedule
- Simulation does not acknowledge or publish a completed tick until the entire schedule returns
- the implemented completion reports exactly how much work committed; a future cancellable outcome must likewise report only work committed before an interruption observed between ticks
- exact workflows can retain an immutable value from the requested cursor rather than racing a changing latest-value slot

The current in-place ECS is not a transactional rollback system. A process trap or future thrown failure halfway through system execution cannot truthfully be described as “the tick never happened”; recoverable rollback would require staging, undo, or checkpoint restoration. The implemented near-term guarantee is that no `await`, successful receipt, or completed publication occurs in the middle of a tick. Cooperative bounded-batch cancellation and its structured interrupted outcome remain proposed; when added, cancellation and ordinary stoppage must be observed between ticks and report the last fully completed cursor. If a future recoverable error escapes halfway through a tick, the Runtime must invalidate that session or restore a known checkpoint before accepting more work; it must not report the previous cursor while continuing from a partially mutated ``World``.

Only one advance request executes at a time in ``SimulationRuntime``'s current `MainActor`-isolated mutation domain. The assembly must still grant one effective logical authority because serialization alone does not define meaningful ordering between competing callers. The ticks committed by one request form a contiguous cursor range. If a future implementation cooperatively yields between ticks for fairness or cancellation, it must keep a non-reentrant request gate so another `advance` call cannot interleave. Cross-runtime rendering or encoding pressure belongs between separate advance requests, not inside a partially coordinated batch.

The current result returns the final presentation value produced by its request. Future exact results do not need to pack every Simulation output into that value; network replication, checkpoints, metrics, and other semantic surfaces should remain deliberately named capabilities.

A batch also need not materialize every large snapshot surface after every internal tick. Simulation completes every tick and preserves the ordering guarantees of any required event lane, while each snapshot contract defines whether it captures the final batch cursor, selected cursors, or every tick.

A cursor identifies one committed position; it does not imply that the corresponding state is still retained, seekable, or recoverable. An exact future workflow requires a returned immutable value or an explicit cursor-addressed retention/rendezvous policy.

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

This means the Simulation Runtime still defines the duration and meaning of one tick, while a real-time driver decides how many such ticks current wall time permits. Future lockstep coordinators and deterministic tests can issue exact requests without pretending that wall time passed.

The ``RealtimeAssembly``-owned ``RealtimeAdvanceDriver`` performs real-time sampling, elapsed-remainder, pause, rebase, input-assignment, and bounded catch-up work through exact requests. ``RealtimeCatchUpPolicy`` caps the indivisible request issued by one wake and chooses whether whole-step overflow is preserved or discarded; the interactive default requests at most four steps and discards overflow. ``Engine`` contains no second wall-clock or partial-schedule path.

## A Simulation Tick Is Indivisible

Each tick committed by a Simulation advance executes one complete invariant fixed-step schedule. Assembly policy chooses whether and when to request that operation; it does not select an arbitrary subset of systems for the operation to run.

The Engine constructs the schedule foundation from one explicit
``SimulationConfiguration`` and composes systems from one
``SimulationBehavior`` only at the controlled ``SimulationSystemSchedule``
stages. Game Content selects both values once, and every Runtime topology passes
the same pair to Simulation. This keeps camera and gameplay behavior consistent
without turning the required system order into a topology-policy surface.

Engine2 should not expose a general `step(mode:)`, public system mask, `cameraOnly` tick, or assembly-defined schedule bucket. Partial execution would give ``SimulationTick`` several meanings and make snapshots, events, and system invariants depend on an implicit run mode. A completed cursor must mean that the whole authoritative schedule committed.

If a genuinely different authoritative operation later appears, it should receive a separately named capability with its own invariants, identity, publications, and tests. It should not increment ``SimulationTick`` while doing less than a Simulation tick.

The current single ordered schedule is a Simulation invariant, not a
topology-policy surface. The current real-time screen consumes the exact camera
from completed Simulation presentation, so no input or Render-side path can
fabricate camera progress without a complete tick. Input responsibilities map as follows:

| Boundary | Responsibility |
| --- | --- |
| ``InputRuntime`` mapping | Maps accepted physical events into context-free translation, interaction, camera, and selection semantics before publication. |
| ``CameraInputSystem`` | Derives orbit state from the current authoritative camera and applies semantic camera commands before transient cleanup. |
| Content behavior systems | Interpret translation, interaction, and selection intent against authoritative ECS selection and control state during a complete tick. |
| ``InputCleanupSystem`` | Interval-local semantic command cleanup runs after input consumers while held semantic intent remains available to later steps. |
| Future metrics and tracing | Observe requests, completed publications, and results without requiring a partial ECS mutation pass. |

Ordinary frozen pause means the absence of advance requests and no cursor change. A future game-specific **soft pause** can remain authoritative game state processed by the complete schedule—for example, movement may stop while network/session rules, scripted world state, or explicitly pause-exempt entities continue. Menu UI and other presentation can progress independently without making a partial Simulation tick. Soft pause is not implemented by suppressing an arbitrary engine system list.

## Input Must Be Attributable to Ticks

Current ``InputSnapshot`` semantics separate held intent from cumulative commands so future assemblies can reuse the same boundary. Held translation and interaction intent persist, while cumulative camera values and the selection-press count let Simulation derive commands across skipped publisher revisions. A future external-control adapter could submit the same `InputEvent` values as the platform adapter and then request a tick, allowing ``InputRuntime`` to apply the same configured mapping.

That is not the only control boundary Engine2 will ever need. Three levels should remain distinct:

1. physical host ingress such as keyboard, pointer, controller, or text callbacks
2. revisioned, context-free semantic intent published by an Input Runtime
3. context-sensitive interpretation against ECS selection and control state, or future tick-addressed game-semantic commands accepted at the Simulation boundary

Network peers, scripts, and tests may eventually prefer semantic commands rather than impersonating a keyboard. Do not expand physical `InputEvent` into a universal command bag to serve those uses.

### Multiple Sources Converge at One Input Authority

The implemented ``InputRuntime`` serializes one platform source, owns its physical state and configured semantic mapping, and publishes one coherent revisioned snapshot. A future multi-source version should also own source-to-channel assignment, merge policy, and serialized acceptance across sources; adapters must not mutate one shared pressed-key set directly. An input-domain channel would group sources into one logical control surface without deciding which player, window, or viewpoint consumes it.

```text
MetalScenePlatformView -------------------+
future controller adapter ----------------+--> InputRuntime --> semantic InputSnapshot
future external-control connector --------+
future bot physical-control adapter -------+
                                 physical ingress
                                 serialized acceptance and mapping
```

Multi-source ingress requires stable source identity and source-local held state. If two sources hold the same key, releasing it from one source must not erase the other's contribution. Detaching or restarting a source neutralizes only that source. Axis combination, pointer ownership, source-to-channel assignment, source priority, and human-versus-bot takeover all require explicit policies; arrival order alone is not a merge policy.

The Input Runtime assigns its own publication revision after accepting and merging source changes. Source-local sequence identities may additionally support deduplication, diagnostics, and replay. A deterministic assembly records the accepted total order whenever concurrent arrival can affect the result.

Input Runtime mapping stops at context-free semantic intent. It can publish translation, interaction, camera, and selection values without deciding which entity receives them or what gameplay action succeeds. Simulation behavior interprets those semantics against authoritative ECS selection and control state at the fixed-tick boundary. A future external service with transport, authentication, and session lifetime remains a peer Runtime; only a deliberately configured physical-control connector participates in Input Runtime fan-in. Game-semantic commands may instead enter through a separately named Simulation-owned control boundary.

Batch advancement must define its input behavior. “Apply this input and advance 30 ticks” is ambiguous unless the contract states whether a one-shot semantic press occurs once, held translation and interaction intent persist, an action repeats every tick, or a distinct per-tick control schedule is supplied. One-step requests are the unambiguous baseline; an optimized batch should carry explicit input scheduling semantics.

Publisher revisions from independent Runtime instances cannot be merged by choosing the numerically newest value. Multiple producers normally converge through one designated Input Runtime. If an assembly-owned arbiter combines several Input Runtime publications, it becomes the effective input authority with its own publisher/session identity and emits one coherent, source-attributed publication through a typed boundary. An ordinary Input Route never mints or compares revisions from unrelated publishers.

The current ``InputSnapshot`` is a single-channel vertical slice. A future multi-seat contract may expose source-partitioned state, channel-addressed snapshots, or several typed output capabilities. It must preserve every identity required by configured routes rather than flattening several players into one aggregate and asking downstream consumers to reconstruct ownership.

### Input Authority and Interpretation Are Distinct

``InputRuntime`` owns physical source facts, serialized acceptance, context-free semantic mapping, publication sessions, and immutable input values. ``RealtimeAssembly`` wires its latest publication to ``RealtimeAdvanceDriver``. Simulation alone interprets that semantic value against authoritative ECS selection and control state at a fixed-tick boundary. The current release has one platform source and one Simulation recipient.

Any future multi-source or multi-recipient design must keep source-local held state, merge policy, recipient baselines, and route transitions explicit. It must not turn platform events into a universal gameplay-command schema.

## There Is At Most One Effective Advance Authority

At most one effective authority may issue progress requests for a Simulation session, and exactly one must be active whenever progress is permitted. Actor serialization alone is not sufficient: two logically independent drivers can still create nondeterministic ordering even if their calls never overlap.

A development assembly can expose real-time cadence and explicit step controls together only if one coordinator arbitrates them. For example, it may suspend real-time demand while an exact-step transaction owns a temporary lease, then explicitly rebase wall-clock timing before resuming.

This also clarifies pause:

- pausing the advance authority means no new simulation ticks occur
- stopping a Runtime is a lifecycle operation
- rendering, inspection, input collection, and other peer-runtime work may continue while Simulation is paused
- a game-specific soft pause, when needed, remains state processed by complete ticks rather than a partial schedule

Every pause policy must also state what happens to input revisions accumulated while no ticks occur. An assembly may ingest them on resume, rebase and discard transient totals, neutralize controls, or journal tick-addressed transitions. Rebasing wall-clock time alone does not resolve accumulated input.

``Engine`` has only complete exact steps. ``RealtimeAdvanceDriver`` makes
ordinary frozen pause the absence of requests. The screen may redraw, but both
its scene and camera remain the exact last completed Simulation publication;
input collection alone cannot create presentation state or a partial tick.

## Publications and Exact Results Serve Different Work

Engine2 needs several explicit boundary shapes rather than one universal bus:

| Boundary | Semantics | Typical use |
| --- | --- | --- |
| Latest snapshot | Newest completed value replaces older values | Onscreen rendering, slow displays, dashboards |
| Ordered event lane | Per-publisher order with explicit buffer/drop policy | Audio occurrences, achievements, recorders |
| Exact request/result | Caller awaits a value correlated to its command | Simulation advance, checkpoint save |
| Durable journal | Explicit retained history and cursoring | Replay, auditing, rollback, time travel |

Cumulative semantic input snapshots recover camera orbit and zoom totals, the latest selection press and its count, and current held translation and interaction intent across skipped publications within one publisher session. Totals and counts restart when the ``InputRevision`` session changes. The count preserves how many selection presses occurred, but the snapshot retains only the latest press payload; it does not recover each press or the order of physical transitions. A future ordered Input event lane is a broadcast publication with an independent sequence position and cancellation lifetime for each subscription, plus explicit buffering and overflow policy for each connection. Storage may be shared or per subscription; one subscriber advancing or dropping its position must not advance another subscriber. When a consumer needs a coherent snapshot followed by ordered transitions, the publisher correlates the snapshot revision with an event-sequence boundary. Retained replay is a deliberate journal policy, not an accidental property of the live lane.

``SimulationPresentationSource`` is intentionally a latest-value boundary. That is correct for a display renderer that can skip superseded states. A future exact workflow must instead receive or retain the immutable value associated with its completed cursor.

Likewise, a multi-tick advance must not imply that events from intermediate ticks are safely recoverable from the final snapshot. A workflow that needs every occurrence must use an ordered lane or explicit journal with a result cursor.

Backpressure belongs to each connection:

- a real-time display normally drops superseded snapshots rather than stalling Simulation
- a cloud video stream may drop stale encoded frames to protect latency
- a durable recorder may fail or stop advancement rather than lose required history

Simulation must not await cross-runtime work from inside a world mutation. Backpressure is applied after a completed tick and before the next request.

## Realtime Interactive Assembly

The current application selects ``RealtimeAssembly`` as one concrete topology,
not as the universal application shape. The App constructs Game Content and
passes it to the assembly, which constructs and connects ``InputRuntime``,
``SimulationRuntime``, and ``RealtimeAdvanceDriver`` with its default policy.
``RealtimeAssemblyView`` connects the host adapter and screen renderer through
narrow runtime capabilities and composes focused controls and toolbar content
into the root UI. `Engine2App` renders the selected
assembly directly. The assembly body owns its root-visibility behavior.
The implemented topology is deliberately concrete:

```text
MetalScenePlatformView --physical events--> InputRuntime --semantic InputSnapshot--> RealtimeAdvanceDriver --> Simulation
          |                                                                                                   |
          +-- drawable and delegate --> MetalRenderer <------------- SimulationPresentationSnapshot ---------+
```

``InputRuntime`` accepts host events only while active, maps them with its
configured bindings, and publishes context-free semantic intent. During ordinary pause the driver requests no Simulation work.
Input publications may change, and Render may redraw, but the latest completed
presentation—including its camera—does not change. This locked path prevents a
camera pose that Simulation has never published. Typed route identity, route
epochs, presentation-owned viewpoints, and multi-window bindings remain future
work.

The real-time driver owns:

- clock sampling
- elapsed-time remainder
- catch-up and maximum-step policy
- backlog overflow policy
- capturing an immutable assignment from the latest Input publication at advance boundaries
- suspending and rebasing wall time around app inactivity

The screen Render path draws according to surface availability or display cadence. It may render the same completed snapshot more than once or skip intermediate snapshots. A future explicit presentation policy may interpolate private Render state without changing Simulation authority. A display callback does not make Render the advance authority.

## Future Topologies

Offline rendering, snapshot export, replay, and agent control are not part of the current release. A future topology should return only when a concrete consumer establishes its ownership, lifecycle, cadence, input boundary, exact-result needs, and failure policy. It must continue to use ``SimulationAdvanceTarget`` rather than calling ``Engine`` or mutating ``World`` directly.

## Broader Assembly Space

The current release keeps one concrete topology:

| Assembly | Advance authority | Notable topology |
| --- | --- | --- |
| ``RealtimeAssembly`` | Monotonic real-time driver | Platform Input, fixed-step Simulation, and latest-value onscreen Render |

Future server, networking, accessibility, terminal, and test topologies can reuse the same ownership rules. They should publish purpose-specific values rather than widening ``SimulationPresentationSnapshot`` into a universal state bag.

## Assemblies May Omit Simulation or Render

The graph must not assume every Runtime is always present.

- a dedicated server can contain Simulation and Network runtimes without Render
- a thin client can render remote presentation snapshots without a local authoritative Simulation Runtime
- an asset preview can construct Render directly from Game Content descriptions
- an input diagnostic can run an Input Runtime without Simulation
- a batch Simulation can publish only metrics or a final state hash

Optional consumers never become prerequisites for Simulation correctness. Outputs for absent consumers go unobserved.

## Lifecycle and Assembly Switching

The live Runtime Assembly, not `Engine2App`, owns topology-specific lifecycle. Its required Game Content initializer constructs the retained graph. Its body establishes view-owned connections before lifecycle policy starts the current driver. The common assembly protocol exposes only construction and the topology's root view; concrete assemblies own their remaining lifecycle surface.

Each assembly body owns its SwiftUI presentation lifecycle. ``RealtimeAssembly`` maps root appearance and disappearance plus scene activity into its generation-guarded policy. It starts Input before its driver and stops and drains the driver before stopping Input. Overlapping transition identity prevents stale asynchronous completion from reversing a newer visibility decision.

A safe start sequence is generally:

1. construct and validate all runtimes and adapters
2. establish typed connections and exact request targets
3. start passive providers and consumers
4. start ingress runtimes
5. start the advance authority last

Failure unwinds in reverse order. Shutdown stops the advance authority first. The current ``SimulationRuntime`` finishes an accepted synchronous batch; cooperative cancellation is not implemented. A future cancellable implementation must observe cancellation only between complete ticks. In-flight GPU work retains its resources until actual completion. Connections are then disconnected and remaining runtimes stop in dependency-safe order.

Switching selected assemblies should initially be a deliberate session transition:

1. suspend the old advance authority
2. drain directed work or request cancellation at supported operation boundaries
3. request a Simulation-owned checkpoint if continuity is required
4. disconnect and stop affected runtimes
5. select, construct, and validate the new assembly type
6. restore only deliberate boundary values
7. begin a new identifiable session or lineage

Do not promise arbitrary hot rewiring while world mutation, GPU submission, or network replication is in flight. Attaching a replaceable latest-value observer may be cheap; replacing the advance authority is a coordinated handoff.

## Assembly Construction and Validation

An assembly should fail before start with useful diagnostics when:

- a required capability has no provider
- more than one active advance authority targets the same Simulation session without an arbiter
- a directed request/result dependency cycle can deadlock
- an ordered connection has no buffer, overflow, or retention policy
- a deterministic assembly includes an unrecorded nondeterministic input or asynchronous result
- a surface renderer has no surface
- multiple input sources fan in without an explicit merge policy
- an input publication flattens source or channel identity required by a configured recipient route
- an exclusive input lane has more than one active recipient in the same route epoch
- a route transition has no publisher-revision/event-sequence cutover, transient baseline, held-control reacquisition, or stale-epoch rejection policy
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

Wall-clock speed and GPU duration determine when requests arrive, not the result of a tick.

A Runtime boundary is a semantic ownership and lifecycle boundary, not a promise of one actor, executor, thread, or pool. Each Runtime owns a concurrency policy that keeps its private mutable state inside its boundary. Cross-runtime work uses immutable `Sendable` values and explicit publication or request/result capabilities.

Concrete assemblies construct their graphs and their View bodies perform framework-required UI work on `MainActor`. `Engine2App` selects Game Content and an assembly type, retains the assembly behind an opaque `some RuntimeAssembly` property, and presents it directly. Any topology-specific SwiftUI lifecycle remains inside the assembly body. That placement does not require potentially long-running Simulation ticks, Render preparation, or other Runtime CPU work whose cadence must remain independent to execute there. The current shared main-actor placement is a transitional implementation constraint, not a requirement for new Runtime capabilities.

Each authoritative Simulation session requires one serialized world-mutation domain. A complete tick executes synchronously within that domain, cannot `await`, and cannot overlap another tick for the same session. Runtimes whose cadences should remain independent must not place long-running work on the same required serial isolation domain merely because one assembly wires them together. Multiple Runtime instances and Simulation sessions may still share bounded execution capacity.

The mechanism remains deliberately open. Swift actors, custom executors, bounded worker pools, helper processes, or other designs can satisfy the contract. A concrete assembly may choose an implementation or process placement; it should not expose raw thread management as Runtime topology.

This direction requires:

- immutable boundary values that explicitly conform to `Sendable`
- serialization or `Codable` contracts where values cross processes
- explicit ordering when ingress arrives from several concurrency domains
- one serialized mutation domain for each authoritative Simulation session
- no `await` inside the mutation of one tick
- advance authorities that share execution capacity to bound batches so one session cannot monopolize that capacity
- any future cooperative cancellation to occur between ticks, never during partial world mutation
- GPU completion remains owned by Render and does not expose mutable backend state across Runtime boundaries

Assembly policy alone does not guarantee bitwise determinism across hardware. Stable system ordering, seeded randomness, recorded external results, content/version fingerprints, and disciplined floating-point behavior remain separate requirements.

## Game Content Remains Orthogonal

One `BasicGameContent` value can feed several assemblies:

- its world builder configures Simulation in real-time, test, or future server assemblies
- its ``SimulationConfiguration/basicGame`` policy configures the foundational Simulation camera consistently across those assemblies
- its render catalog configures screen or future alternate render consumers
- future text, audio, or accessibility presentation mappings configure the runtime that performs those projections

Game Content does not select cadence, start runtimes, own caches, or coordinate requests. The App constructs its selected Game Content and passes it through ``RuntimeAssembly/init(using:)``. Each assembly supplies the relevant portions to the Runtimes in its topology.

## Current Implementation Mapping

| Current type or coverage | Implemented responsibility |
| --- | --- |
| ``SimulationSessionID`` and ``SimulationCursor`` | Session-qualified identity for committed Simulation positions |
| ``SimulationAdvanceTarget`` and ``SimulationRuntime`` | Serialized exact-step request boundary, expected-cursor validation, immutable input assignment, complete schedule execution, and correlated completed publication |
| ``RuntimeAssembly`` | View-refining Game Content construction boundary retained directly by the App |
| ``RealtimeAssembly`` and ``RealtimeAdvanceDriver`` | Real-time Input-to-Simulation composition, bounded catch-up, pause policy, lifecycle coordination, and screen presentation |
| ``RenderFrame``, ``MetalFrameEncoder``, and ``MetalRenderer`` | Snapshot-camera projection, view-independent frame encoding, and MetalKit-specific screen submission and presentation |
| Focused and integration coverage | Exact advancement, driver lifecycle, Input attribution, screen projection, reusable encoding, and Game Content-driven real-time topology construction |

Offscreen rendering, image encoding, offline capture, replay coordination, and agent sessions are not current implementation surfaces.

## Current Verification

Automated coverage exercises:

- exact multi-step advancement, stale-cursor rejection, and detached cursor-correlated results
- simultaneous requests with the same expected cursor, which cannot both commit
- first-step input and orbit-command attribution for multi-step requests
- real-time elapsed accumulation, bounded catch-up, overflow treatment, pause and resume rebasing, and cursor-mismatch faulting
- assembly lifecycle ordering, asynchronous drain, rebuild synchronization, SwiftUI value copies, and independent graphs from separate construction
- complete Engine schedule ordering, input cleanup, completed publication, and session replacement
- exact screen-camera projection and view-independent Metal frame encoding
- ``RuntimeAssembly`` conformance, Game Content construction, and direct App hosting

Future topology slices should add focused coverage for their authority, lifecycle, backpressure, cancellation, and retention rules before joining the release architecture.

## Architectural Traps

Avoid:

- creating a `TickRuntime` that owns Simulation's fixed delta or tick counter
- using an ECS `System` type for top-level cadence or assembly work
- letting a Render Runtime, Network Runtime, or view call ``Engine`` or mutate ``World``
- exposing elapsed `deltaTime` as the only portable advancement API
- allowing several drivers to race and relying on actor serialization to make the order meaningful
- using a camera-only, tooling-only, or caller-selected system bucket as a second meaning of Simulation tick
- assuming one render frame equals one simulation tick
- feeding Render culling, a resolved camera, or Audio mixing results back into AI or gameplay perception
- allowing Render or Audio to consume and interpret physical input events or semantic input snapshots
- using one destructive input cursor or baseline for several recipients
- allowing presentation input accumulated while paused to replay as gameplay input on resume
- losing intermediate events silently during a multi-tick request
- identifying state by a resettable bare tick
- turning assemblies into a global service locator, event bus, or mutable runtime registry
- encoding the graph in `Any`, strings, or a bag of optionals
- forcing device input and network commands into one lowest-common-denominator schema
- turning ``SimulationPresentationSnapshot`` into an exhaustive mirror of ``World``
- treating an event as a command or an ordinary event stream as a durable journal
- allowing render sampling quality to change Simulation's fixed step implicitly
- allowing a slow optional consumer to block real-time Simulation accidentally
- retaining unbounded history for every assembly
- hot-swapping advance authority while work is in flight
- creating a Runtime for every stateless adapter or formatter
- treating independent Simulation sessions as adapters inside one mutable World-owning Runtime
- equating one Runtime with exactly one actor, executor, operating-system thread, or private thread pool
- executing potentially long-running Runtime CPU work on `MainActor` merely because assembly construction or view presentation begins there
- putting terminal, network, or Metal backend concerns into ECS state
- assuming every valid assembly contains both Simulation and Render

## Durable Invariants

Future assembly work should preserve these rules:

1. The Simulation Runtime is the sole owner of authoritative world mutation.
2. Exactly one complete Simulation tick executes at a time per session.
3. At most one effective advance authority is active per Simulation session; exactly one authority or arbiter exists whenever progress is permitted.
4. Simulation owns fixed-step meaning, schedule, cursor, and completed publications; external policy owns when progress is requested.
5. Wall time, display time, network time, and simulation time remain distinct.
6. Input and semantic control enter authoritative Simulation state only at safe, attributable tick boundaries.
7. Reset, rebuild, restore, and fork produce unambiguous session or lineage identity.
8. Exact workflows receive exact immutable values; latest-value consumers may skip superseded values.
9. Snapshots, events, commands, results, and journals keep distinct semantics.
10. Optional consumers do not change Simulation correctness.
11. Consumers own their projections, backend state, caches, and physical I/O.
12. Backpressure and retention policy are explicit per connection.
13. Any future cooperative cancellation is observed only between complete ticks or other explicitly supported operation boundaries; recoverable failures do not expose partially mutated Simulation as a valid cursor and report the last committed cursor.
14. Runtime topology is explicit in the selected concrete Runtime Assembly; the App selects that type without making its capabilities globally discoverable mutable state.
15. Multiple complete assemblies can coexist without contaminating one another.
16. A Simulation cursor advances only after the complete invariant schedule has been evaluated; assemblies do not select partial system subsets.
17. Each Runtime owns the concurrency policy for its private mutable state; cross-runtime mutable implementation state never escapes its boundary.
18. Runtime ownership does not require a dedicated actor, executor, thread, or pool, but independently advancing Runtimes must not be forced through one required serial execution domain.
19. Input Runtime owns physical source facts and context-free semantic mapping, the Runtime Assembly owns routes, and recipients own contextual interpretation; no recipient destructively consumes another recipient's input.
20. Presentation state cannot feed back into Simulation except through a deliberate Simulation-owned command accepted at a tick boundary.

## Open Design Questions

The following details should remain open until a concrete future slice provides evidence:

- whether future exact output surfaces return their values directly or use a cursor-addressed rendezvous
- the optimized representation of per-tick input/control batches
- the first typed input-publisher, Input Route, input-channel, route-epoch, cutover, and independent consumer-baseline contracts
- how Runtime internals migrate away from the project-wide `MainActor` default while preserving App, UI, and framework-required isolation
- which Runtime implementations require distinct isolation domains and which may share bounded execution capacity
- whether concrete isolation uses actors, custom executors, another in-process mechanism, helper processes, or a combination
- which Render preparation work can leave view-facing isolation
- interpolation contracts for high-refresh display presentation
- launch diagnostics and recovery policy for topology-specific dependencies that fail outside ``RuntimeAssembly`` construction

These mechanics should be selected incrementally without compromising the ownership and cadence separation defined here.

## Related Direction

- <doc:Runtime-Architecture>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
- <doc:Engine-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
- <doc:Rendering-Architecture>
- <doc:System-Scheduling>
