# Runtime Communication

This article defines the proposed communication model between Engine2 runtimes.

## Status

Partially implemented.

The Input Runtime now publishes a revisioned latest ``InputSnapshot`` through `PInputSnapshotSource`. In the real-time assembly, ``RealtimeAdvanceDriver`` captures immutable input into each ``SimulationAdvanceRequest``; at a connection transition it pairs the activation baseline with the later request-time publication so Simulation can apply both atomically at an exact fixed-step boundary. The Simulation Runtime also publishes a latest completed ``SimulationPresentationSnapshot``, which Render projects into a private ``RenderFrame``. Ordered event publication, additional semantic snapshot surfaces, subscription lifetimes, retained history, generalized exchange infrastructure, and non-main-actor delivery remain proposed.

## Runtimes Publish State and Occurrences

A runtime may publish two complementary kinds of immutable output:

- a **Snapshot** describing state within that runtime's authority at a completed point in time
- **Events** describing occurrences within that runtime's authority

The two outputs answer different questions:

- a snapshot answers "what is true now?"
- an event answers "what happened?"

This is a common communication shape rather than a requirement that every runtime always produce both outputs. A runtime should publish only the state and occurrences that form a meaningful boundary for its responsibility.

For example:

| Publisher | Snapshot state | Example events |
| --- | --- | --- |
| Input Runtime | held keys and pointer state, including cumulative motion and scroll totals | future ordered key, button, and pointer transitions |
| Simulation Runtime | purpose-specific completed state such as abstract presentation | collision occurred, weapon fired, level completed |
| Achievement Runtime | current awarded and tracked achievement state | achievement awarded |

Snapshots and events are publisher-owned vocabulary. A runtime defines the meaning and schema of facts within its own authority without naming the runtimes that may consume them.

## Snapshots Publish Deliberate Semantic Surfaces

A runtime may publish more than one snapshot when it owns several distinct semantic surfaces. Consumer-agnostic publication means that the publisher does not name or depend on receiving runtimes, their implementations, lifecycles, or cadences. It does not require one universal value designed without a use case.

The current ``SimulationPresentationSnapshot`` is the first such surface. It publishes a completed ``SimulationCursor``, camera state, and ``EntityPresentationSnapshot`` values for entities carrying explicit abstract presentation state. It excludes non-presented entities as well as:

- ``World`` and mutable entity-object references
- component-store sparse and dense representation
- systems, schedules, clocks, and fixed-step accumulation
- temporary collision, pathfinding, or per-system work storage
- tasks, locks, services, caches, and backend resources
- any other machinery used to execute the Simulation Runtime rather than describe completed game state

The presentation snapshot contains enough semantic fidelity for presentation consumers to derive private models without exposing simulation implementation. A future audio, networking, inspection, or other continuous-state need may justify another explicitly named Simulation Runtime snapshot. It should not automatically expand this presentation contract or create a universal bag of all simulation state.

A restorable `GameCheckpoint` is a different value. Saving, rollback, or deterministic continuation may require random-generator state, private timers, behavior state, or other details that do not belong in ordinary live publications. The App should coordinate checkpoint creation as a deliberate request/result workflow, and a Storage Runtime may persist the simulation-owned checkpoint without interpreting it.

## Consumers Own Their Projections

A receiving runtime transforms a publisher-owned snapshot into its own private operational model.

```text
SimulationRuntime
    publishes SimulationPresentationSnapshot
                        |
                        +--> RenderRuntime projects RenderFrame
                        +--> optional capture or inspection tooling
```

There is no jointly owned snapshot in this flow:

- the publisher owns the snapshot it publishes
- the consumer owns its projection and any private snapshot or cache it derives
- the App owns the connection between the two runtime boundaries

For rendering, `SimulationPresentationSnapshot` contains backend-neutral completed presentation state. The Render Runtime selects and transforms the fields it needs into render-oriented data such as matrices, resolved presentation keys, visibility results, sort keys, or batches. The Simulation Runtime does not define those render details.

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
InputMetalView -- InputEvent -------------> InputRuntime
InputRuntime -- latest InputSnapshot -----> RealtimeAdvanceDriver
RealtimeAdvanceDriver
    +-- SimulationAdvanceRequest ---------> SimulationRuntime
SimulationRuntime
    +-- SimulationPresentationSnapshot ---> RenderRuntime
    +-- selected SimulationEvent ----------> AudioRuntime
    +-- selected SimulationEvent ----------> AchievementRuntime
```

Additional consumers of continuous simulation state should receive deliberately named publisher-owned snapshots whose schemas match those semantic surfaces. They should not be added implicitly to one exhaustive `SimulationSnapshot`.

This topology should use explicit, strongly typed connections. Engine2 should not introduce a process-global event bus, a process-global snapshot database, or a service locator that allows runtimes to discover arbitrary publishers.

A shared infrastructure type resembling `RuntimeOutput<Snapshot, Event>` may eventually provide reusable mechanics, but that name and API are illustrative rather than selected design. The important constraints are:

- the publisher retains exclusive write authority
- consumers receive read-only immutable values
- each connection is visible at App composition
- snapshot and event types remain strongly typed by their publishing authority
- adding or removing a consumer does not change publisher correctness

An App-owned router or hub may be an implementation detail, but it must not erase the explicit typed topology or become globally discoverable mutable state.

The implemented input connection uses two narrow capabilities. Platform adapters such as `InputMetalView` submit `InputEvent` values to ``InputRuntime`` through `PInputEventSink`. ``RealtimeAdvanceDriver`` receives only the immutable latest `InputSnapshot` through `PInputSnapshotSource` and captures it in the directed exact request. The App owns both connections. `InputEvent` is therefore host ingress, not a runtime-published event stream and not a direct call into Simulation.

## Directed Advancement Needs an Exact Result

Advancing Simulation is neither a snapshot nor an event. It is a deliberate request to perform authoritative work, so the App or an App-owned configuration coordinator routes it through the narrow Simulation-owned ``PSimulationAdvanceTarget`` request/result capability.

The requester may be a real-time driver, offline capture workflow, MCP session coordinator, network lockstep policy, replay driver, or test. It decides when and how many ticks to request; ``SimulationRuntime`` remains the only owner that executes the complete fixed-step schedule, mutates ``World``, advances the session-qualified cursor, and publishes committed outputs.

Latest-value publication remains correct for consumers allowed to skip superseded states. It is not sufficient for an offline or MCP workflow that must render exactly the state produced by its own command. Such a workflow needs an immutable exact result or cursor-addressed rendezvous labeled with a Simulation session identity and tick. A cursor identifies state but does not imply that state is retained. A multi-tick result must expose enough initial/final cursor correlation for a separately configured ordered event lane or journal to recover required occurrences; the final snapshot does not imply their retention.

See <doc:Runtime-Configurations-and-Advancement> for the implemented exact boundary and the proposed authority, idempotency, backpressure, and broader configuration model.

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

The implemented input boundary demonstrates latest-value behavior. `InputRevision` identifies the publisher session and version represented by each `InputSnapshot`. Held keys and buttons are state in that value. Within one publisher session, pointer motion and scroll are cumulative totals, so Simulation can derive the complete change between the revisions it samples even when host events and fixed ticks do not run one-for-one. Re-reading the same revision does not replay a transient delta.

Ordered discrete transitions are a separate future lane. If key-down/up ordering, text composition, replay, or other occurrence history must survive skipped snapshots, the Input Runtime will need an explicit event sequence plus buffering or journaling policy. The platform-facing `InputEvent` ingress does not provide those publication guarantees by itself. A future snapshot revision and publisher-local event sequence may define a consistent boundary between the lanes; the atomic-publication and subscription mechanism remains unresolved.

## Durable History Is Explicit

Ordinary runtime publication is not a database.

If replay, auditing, debugging, networking, or another feature requires retained history, an explicit recorder or journal can subscribe to selected runtime outputs and own that retention policy. Durable history should not impose storage or delivery guarantees on every ordinary runtime connection.

Likewise, a Storage Runtime may publish its own status snapshot and completion events, but save and load workflows remain deliberate App-coordinated requests and results rather than ambient access to a snapshot database.

## Open Implementation Questions

The following mechanics remain intentionally unresolved:

- typed subscription APIs beyond the implemented latest input and simulation-presentation sources
- ordered Input Runtime transition publication and its buffering or journaling policy
- whether exchanges use actors, async sequences, callbacks, lock-free slots, or another mechanism
- ownership and cancellation of subscription lifetimes
- per-connection event buffering, backpressure, and drop policies
- atomic correlation between a snapshot revision and its publisher's event sequence
- whether snapshot storage uses a single latest slot, front/back values, or a short ring
- efficient immutable storage and copy behavior for large runtime snapshots
- how consumer-defined Game Content contributes strongly typed state to purpose-specific snapshots without a closed component registry
- which histories, if any, are journaled for debugging, replay, or networking

These choices should preserve the ownership model in this article rather than replacing it with hidden global coordination.

## Related Direction

- <doc:Runtime-Architecture>
- <doc:Runtime-Configurations-and-Advancement>
- <doc:Game-Content-Architecture>
- <doc:Rendering-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
