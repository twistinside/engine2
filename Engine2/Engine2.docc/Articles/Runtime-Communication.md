# Runtime Communication

This article defines the proposed communication model between Engine2 runtimes.

## Status

Partially implemented.

The Input Runtime maps physical device state through `InputMappingConfiguration` and publishes a revisioned latest semantic ``InputSnapshot`` through `InputSnapshotSource`. The snapshot contains context-free translation and interaction intent plus cumulative camera and selection values; it does not identify an entity or expose physical keys and buttons. In the real-time assembly, ``RealtimeAdvanceDriver`` captures immutable input into each ``SimulationAdvanceRequest``; at a connection transition it pairs the activation baseline with the later request-time publication so Simulation can apply both atomically at an exact fixed-step boundary. Simulation then interprets the semantic values using authoritative ECS selection and player-control state. The optional orbit-circularization command uses a separate SwiftUI-to-assembly path but joins that same cursor-qualified request and is imported only for its first tick, where it may engage per-entity Simulation-owned autopilot state. Once engaged, that state persists independently of the request until Simulation completes or aborts the burn; later ticks do not replay the command. The Simulation Runtime separately publishes a latest completed ``SimulationPresentationSnapshot``. The current screen renderer projects that value with `snapshot.camera` exactly, producing a private ``RenderFrame`` that carries the Simulation cursor and no explicit-viewpoint attribution.

`MetalSceneView` hosts one `MetalScenePlatformView`. The single platform `MTKView` supplies the drawable surface used by `MetalRenderer` and submits each physical host ``InputEvent`` directly to ``InputRuntime`` through `InputEventSink`. It contains no semantic mapping, gameplay decision, or render encoding. The Render path does not interpret those events, and ``RealtimeAssembly`` is not an input router. Ordered event publication, typed multi-source routes, future presentation routes, multi-window output bindings, additional semantic snapshot surfaces, subscription lifetimes, retained runtime publication history, generalized exchange infrastructure, and non-main-actor delivery remain proposed.

## Runtimes Publish State and Occurrences

A runtime may publish two complementary kinds of immutable output:

- a **Snapshot** describing state within that runtime's authority at a completed point in time
- **Events** describing occurrences within that runtime's authority

The two outputs answer different questions:

- a snapshot answers "what is true now?"
- an event answers "what happened?"

This is a common communication shape rather than a requirement that every runtime always produce both outputs. A runtime should publish only the state and occurrences that form a meaningful boundary for its responsibility.

For example:

| Publisher | Snapshot state | Potential event facts |
| --- | --- | --- |
| Input Runtime | held translation and interaction intent plus cumulative camera and selection values | future ordered semantic transitions or text input |
| Simulation Runtime | purpose-specific completed state such as abstract presentation | collision occurred, weapon fired, level completed |
| Achievement Runtime | awarded and tracked achievement state | achievement awarded |

Snapshots and events are publisher-owned vocabulary. A runtime defines the meaning and schema of facts within its own authority without naming the runtimes that may consume them.

## Snapshots Publish Deliberate Semantic Surfaces

A runtime may publish more than one snapshot when it owns several distinct semantic surfaces. Consumer-agnostic publication means that the publisher does not name or depend on receiving runtimes, their implementations, lifecycles, or cadences. It does not require one universal value designed without a use case.

The current ``SimulationPresentationSnapshot`` is the first such surface. It publishes a completed ``SimulationCursor``, a Simulation-authored camera, and ``EntityPresentationSnapshot`` values for entities carrying explicit abstract presentation state. That camera is the exact authority for the current real-time screen. The snapshot excludes non-presented entities as well as:

- ``World`` and mutable entity-object references
- component-store sparse and dense representation
- systems, schedules, clocks, and fixed-step accumulation
- temporary collision, pathfinding, or per-system work storage
- tasks, locks, services, caches, and backend resources
- any other machinery used to execute the Simulation Runtime rather than describe completed game state

The presentation snapshot contains enough semantic fidelity for presentation consumers to derive private models without exposing simulation implementation. A future audio, networking, or other continuous-state need may justify another explicitly named Simulation Runtime snapshot. It should not automatically expand this presentation contract or create a universal bag of all simulation state.

The selected-entity SwiftUI inspector uses a different boundary. A narrow Simulation-owned source exposes only the currently selected live entity facade, and the inspector conditionally renders sections from that facade's capability protocols. The source remains read-only. ``OrbitCircularizable`` supplies the live delta-velocity reserve and minimum burn duration from authoritative Simulation state. A separate focused callback passes the displayed entity's full ``EntityID`` through ``RealtimeAssemblyViewModel`` to ``RealtimeAdvanceDriver`` when the player requests orbit circularization. The inspector does not receive `World`, inspect component-store representation, mutate the facade, or require gameplay fields in ``SimulationPresentationSnapshot``. Selection remains authoritative ECS state even though the inspector consumes an ergonomic entity view.

A restorable `GameCheckpoint` is a different value. Saving, rollback, or deterministic continuation may require random-generator state, private timers, behavior state, or other details that do not belong in ordinary live publications. The App should coordinate checkpoint creation as a deliberate request/result workflow, and a Storage Runtime may persist the simulation-owned checkpoint without interpreting it.

## Consumers Own Their Projections

A receiving runtime transforms a publisher-owned snapshot into its own private operational model.

```text
SimulationRuntime
    +-- SimulationPresentationSnapshot -------------> screen RenderFrame
    +-- selected-entity source ---------------------> SwiftUI inspector
SwiftUI inspector -- EntityID callback -------------> RealtimeAssembly
```

There is no jointly owned snapshot in this flow:

- the publisher owns the snapshot it publishes
- the consumer owns its projection and any private snapshot or cache it derives
- the App-owned Runtime Assembly owns the connection between the two runtime boundaries

For rendering, `SimulationPresentationSnapshot` contains backend-neutral completed presentation state. The Render Runtime selects and transforms the fields it needs into render-oriented data such as matrices, resolved presentation keys, visibility results, sort keys, or batches. The Simulation Runtime does not define those render details.

In the implemented screen path, `MetalRenderer` samples one latest ``SimulationPresentationSnapshot`` and calls `RenderFrame(projecting:)`. ``RenderFrame`` uses the snapshot camera exactly and retains the source ``SimulationCursor``. Repeated draws may observe the same completed cursor, but the screen camera cannot change until Simulation publishes a new completed value.

Rendering is snapshot-driven. It may ignore intermediate simulation snapshots and converge on the latest completed value. Any occurrence that must remain visible, such as a muzzle flash or explosion, therefore needs snapshot-visible identity and lifetime rather than depending on Render receiving a transient simulation event.

## Events Remain an Independent Lane

Events are not commands and are not incomplete snapshots. They are immutable facts that occurred within the publisher's authority.

A consumer may use snapshots, events, or both:

- Render consumes simulation state through snapshots.
- Audio may eventually use a separately named Simulation Runtime snapshot for continuous listener and emitter state, plus events for one-shot occurrences.
- Achievement logic may use current progress state, occurrence events, or durable counters depending on its correctness requirements.
- Tooling may observe both without becoming required for publisher correctness.

Consumers that begin late can converge from the latest snapshot. Ordinary ephemeral events published before subscription may be intentionally missed. If a consumer must recover historical occurrences, that requirement belongs in durable snapshot state or an explicit journal rather than silently changing ordinary event semantics.

## The App Wires Typed Publication Boundaries

The App remains the composition root. It decides which runtime outputs are connected to which runtime inputs.

```text
MetalScenePlatformView -- InputEvent ------> InputRuntime
InputRuntime -- latest InputSnapshot -----> RealtimeAdvanceDriver
RealtimeAdvanceDriver
    +-- SimulationAdvanceRequest [optional OrbitCircularizationCommand] --> SimulationRuntime
SimulationRuntime
    +-- SimulationPresentationSnapshot ------> MetalRenderer
    +-- selected-entity source --------------> SwiftUI inspector
SwiftUI inspector -- EntityID callback ------> RealtimeAssembly
RealtimeAssembly -- staged orbit command ----> RealtimeAdvanceDriver
SimulationRuntime
    +-- future selected SimulationEvent ---> AudioRuntime
    +-- future selected SimulationEvent ---> AchievementRuntime
```

Additional consumers of continuous simulation state should receive deliberately named publisher-owned snapshots whose schemas match those semantic surfaces. They should not be added implicitly to one exhaustive `SimulationSnapshot`.

This topology should use explicit, strongly typed connections. Engine2 should not introduce a process-global event bus, a process-global snapshot database, or a service locator that allows runtimes to discover arbitrary publishers.

A shared infrastructure type resembling `RuntimeOutput<Snapshot, Event>` may eventually provide reusable mechanics, but that name and API are illustrative rather than selected design. The important constraints are:

- the publisher retains exclusive write authority
- consumers receive read-only immutable values
- each connection is visible at App composition
- snapshot and event types remain strongly typed by their publishing authority
- adding or removing a consumer does not change publisher correctness

An assembly-owned router or hub may be an implementation detail, but it must not erase the explicit typed topology or become globally discoverable mutable state.

The implemented input connection uses narrow capabilities and one recipient. `MetalScenePlatformView` submits physical `InputEvent` values directly to ``InputRuntime`` through `InputEventSink`; the Runtime ignores them while its publication lifecycle is stopped and otherwise updates private device state, performs context-free mapping, and publishes a semantic snapshot. ``RealtimeAdvanceDriver`` receives only that immutable latest `InputSnapshot` through `InputSnapshotSource` and captures it in the directed exact request. ``RealtimeAssembly`` owns both connections, and `MetalSceneView` installs the single platform surface. `InputEvent` is therefore host ingress, not a runtime-published event stream, a presentation command, or a direct call into Simulation. The orbit-assist callback does not weaken that rule: it bypasses Input Runtime and stages one typed Simulation command through the sole real-time advance authority. Source identity, route epochs, independent recipient baselines, exclusivity, presentation control, and multi-window binding semantics remain future typed-routing work.

## Directed Advancement Needs an Exact Result

Advancing Simulation is neither a snapshot nor an event. It is a deliberate request to perform authoritative work, so the App-owned assembly or its focused coordinator routes it through the narrow Simulation-owned ``SimulationAdvanceTarget`` request/result capability.

The requester may be the real-time driver, a deterministic test, or a future coordinator. It decides when and how many ticks to request; ``SimulationRuntime`` remains the only owner that executes the complete fixed-step schedule, mutates ``World``, advances the session-qualified cursor, and publishes committed outputs.

The real-time orbit assist demonstrates request-attributed gameplay control without adding a second advance authority. ``RealtimeAdvanceDriver`` stages ``OrbitCircularizationCommand`` behind a generation tag and captures it in the next exact request. Completion retires only the captured generation, so a newer click received while that request is in flight remains pending; session synchronization clears stale pending work. After cursor validation, ``SimulationRuntime`` makes the command visible only to the first tick of a multi-step request, and ``OrbitCircularizationSystem`` consumes and clears it during `inputConsumption`. A command that passes Simulation's maneuver checks engages persistent per-entity Simulation-owned autopilot state. During that tick and while the state remains engaged on later ticks, ``OrbitCircularizationAutopilotSystem`` runs after gravity and before manual flight control. The system suppresses manual translation and continues the finite burn under current thrust, fuel, live mass, and normal integration without another request.

Latest-value publication remains correct for consumers allowed to skip superseded states. A future workflow that must consume exactly the state produced by its own command needs an immutable exact result or cursor-addressed rendezvous labeled with a Simulation session identity and tick. A cursor identifies state but does not imply that state is retained. A multi-tick result must expose enough initial/final cursor correlation for a separately configured ordered event lane or journal to recover required occurrences; the final snapshot does not imply their retention.

See <doc:Runtime-Assemblies-and-Advancement> for the implemented exact boundary and the proposed authority and broader assembly model.

## Snapshots and Events Need Different Delivery Semantics

Snapshots naturally use latest-value semantics:

- a newer completed snapshot may replace an older one
- a slow consumer may skip intermediate snapshots
- a late consumer can begin from the latest value
- optional short history, such as interpolation frames, belongs to a deliberate consumer or exchange policy

Events naturally use ordered-stream semantics:

- ordering is meaningful within one publisher's authority
- broadcast consumers require independent subscription positions
- buffering, backpressure, and drop behavior may differ by connection
- there is no assumed universal ordering across different runtimes and cadences

The implemented input boundary demonstrates latest-value behavior. `InputRevision` identifies the publisher session and version represented by each `InputSnapshot`. Held translation and interaction intent persist until a later publication changes them. Camera orbit and zoom are cumulative totals, and the latest normalized selection press is paired with a cumulative press count. Simulation can therefore derive the complete camera interval and consume a selection press at most once even when host events and fixed ticks do not run one-for-one. Re-reading the same revision does not replay a transient delta or press. When the platform surface loses keyboard focus or its window resigns key status, it submits a physical focus-loss event. If a key is held, ``InputRuntime`` clears its held-key state and republishes the resulting semantic value so a missed key-up cannot leave gameplay input stuck.

Ordered discrete transitions are a separate future lane. If key-down/up ordering, text composition, replay, or other occurrence history must survive skipped snapshots, the Input Runtime will need an explicit event sequence plus buffering or journaling policy. The platform-facing `InputEvent` ingress does not provide those publication guarantees by itself. A future snapshot revision and publisher-local event sequence may define a consistent boundary between the lanes; the atomic-publication and subscription mechanism remains unresolved.

## Durable History Is Explicit

Ordinary runtime publication is not a database.

If replay, auditing, debugging, networking, or another feature requires retained history, an explicit recorder or journal can subscribe to selected runtime outputs and own that retention policy. Durable history should not impose storage or delivery guarantees on every ordinary runtime connection.

Likewise, a Storage Runtime may publish its own status snapshot and completion events, but save and load workflows remain deliberate assembly-coordinated requests and results rather than ambient access to a snapshot database.

## Open Implementation Questions

The following mechanics remain intentionally unresolved:

- typed subscription APIs beyond the implemented latest input and simulation-presentation sources
- typed input routes, route epochs, independent recipient baselines, future presentation recipients, and multi-window/output bindings
- ordered Input Runtime transition publication and its buffering or journaling policy
- whether exchanges use actors, async sequences, callbacks, lock-free slots, or another mechanism
- ownership and cancellation of subscription lifetimes
- per-connection event buffering, backpressure, and drop policies
- atomic correlation between a snapshot revision and its publisher's event sequence
- whether future generalized snapshot exchanges use a single latest slot, front/back values, or a short ring
- efficient immutable storage and copy behavior for large runtime snapshots
- how consumer-defined Game Content contributes strongly typed state to purpose-specific snapshots without a closed component registry
- which histories, if any, are journaled for debugging, replay, or networking

These choices should preserve the ownership model in this article rather than replacing it with hidden global coordination.

## Related Direction

- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Game-Content-Architecture>
- <doc:Rendering-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
