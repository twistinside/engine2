# Runtime Configurations and Advancement

This article proposes how Engine2 can assemble different runtime graphs for interactive play, offline rendering, agent control, servers, tests, replays, and deliberately unusual presentation backends without changing the authoritative simulation model.

## Status

Proposed architectural direction.

The existing code already has the most important enabling seams: ``Engine/step(inputSnapshot:)`` can execute one deterministic fixed step, ``SimulationPresentationSnapshot`` is detached from live ECS state, and ``RenderFrame/project(from:)`` is a Render-owned projection. The current ``SimulationRuntime`` still constructs and owns one wall-clock ``SimulationLoop``, however, so only the real-time arrangement is available through the app-facing lifecycle today.

The overall feasibility is high. The work is primarily a separation of pacing, coordination, and exact-result delivery from simulation execution rather than a replacement of the ECS core.

## The Architectural Thesis

Engine2 applications should be explicit assemblies of independently owned runtimes. A configuration selects which runtimes exist, how their typed boundaries connect, and which policy decides when Simulation may advance.

The decisive separation is:

> A configuration-selected **advance authority** decides when and how much progress to request. The Simulation Runtime remains the only owner of what a simulation tick means and the only executor that can produce one.

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
- App-owned adapters and coordinators
- connection tasks, subscriptions, and cancellation tokens
- at most one active advance authority for each Simulation Runtime
- lifecycle ordering and failure unwinding

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
| Advance authority | Wall clock, display wake-up, offline timeline, MCP caller, network barrier, replay, test, fastest possible |
| Progress request | Exact tick, bounded tick batch, target cursor, finite job horizon |
| Output surface | Presentation, audio, network replication, inspection, metrics, state hash, checkpoint |
| Presentation backend | Onscreen Metal, offscreen Metal, text, video, audio-only, physical device, none |
| Delivery semantics | Latest replaceable, exact request/result, ordered buffered, durable journal |
| Cardinality | One Simulation with many consumers, many isolated Simulations, client/server or validation pairs, render-only assembly |
| Lifetime | Continuous application, finite job, request-driven session, one-shot test |
| Backpressure | Drop, coalesce, bound, block the next request, persist |
| Determinism | Best-effort live, recorded external inputs, reproducible exact-step session |
| Execution location | Same actor, another executor, helper process, remote transport |

These choices must not be accidentally fused:

- onscreen rendering does not imply real-time Simulation
- offscreen rendering does not imply that a Simulation Runtime exists
- MCP input does not imply that MCP owns Render or Simulation
- headless operation does not imply maximum-speed advancement
- a display callback does not imply one render frame per simulation tick
- high render quality does not imply a smaller or variable simulation step

Initially, concrete typed composition functions or configuration types are preferable to a universal runtime-graph DSL. Avoid a mutable dictionary of services, `Any`-typed ports, string-selected runtime classes, or one structure full of optional runtimes and Boolean mode flags. Those approaches hide invalid assemblies until execution.

An application with a finite built-in catalog may use a strongly typed enum to select `realtime`, `offlineCapture`, or `mcp` construction. Engine consumers should still be able to define new concrete assemblies without extending a closed Engine2-wide enum.

Configurations select among declared typed capabilities and may choose per-connection buffering, retention, and backpressure policy where the publisher's contract permits it. They do not redefine publisher-owned vocabulary or reinterpret a latest-value source as an exact result or durable journal.

## Advancement Is a Directed Boundary

Snapshots and events are consumer-agnostic publications. Advancing Simulation is different: it is a deliberate command with a correlated result.

The Simulation Runtime should eventually expose a narrow, Simulation-owned advance capability. The exact API remains proposed, but its semantic shape should resemble:

```swift
struct SimulationSessionID: Hashable, Sendable {
    let rawValue: UUID
}

struct SimulationCursor: Hashable, Sendable {
    let sessionID: SimulationSessionID
    let tick: SimulationTick
}

struct SimulationStepCount: Hashable, Sendable {
    // Construction validates that rawValue is greater than zero.
    let rawValue: UInt32
}

struct SimulationCompletedStepCount: Hashable, Sendable {
    // Zero is valid when interruption occurs before the first requested tick.
    let rawValue: UInt32
}

struct SimulationAdvanceRequest: Sendable {
    let expectedCursor: SimulationCursor?
    let stepCount: SimulationStepCount
}

struct SimulationAdvanceResult: Sendable {
    let initialCursor: SimulationCursor
    let finalCursor: SimulationCursor
    let completedStepCount: SimulationCompletedStepCount
    let finalPresentationSnapshot: SimulationPresentationSnapshot
}

enum SimulationAdvanceOutcome: Sendable {
    case completed(SimulationAdvanceResult)
    case interrupted(SimulationAdvanceResult, SimulationAdvanceStopReason)
    case rejected(currentCursor: SimulationCursor, SimulationAdvanceRejection)
}

@MainActor
protocol PSimulationAdvanceTarget: AnyObject {
    func advance(_ request: SimulationAdvanceRequest) async -> SimulationAdvanceOutcome
}
```

These names and fields are illustrative. `@MainActor` reflects the feasible first implementation, while the `Sendable` conformances describe the desired transport-safe value boundary. ``SimulationPresentationSnapshot`` and its complete value graph would need explicit concurrency review and conformance before this sketch compiled as written. Neither `async` nor actor isolation by itself establishes the request-ordering rules below.

The request deliberately omits one universal control payload. The current physical-input MVP could atomically stage an ``InputSnapshot`` immediately before advancement, while replay, networking, bots, or Game Content may later require tick-addressed semantic control batches. The selected ingress must be attributable to the request without making keyboard-shaped state the permanent Simulation command vocabulary.

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

Only one advance request may be active per Simulation session. The ticks committed by one bounded request form a contiguous cursor range. If the implementation yields between ticks to preserve executor fairness or observe cancellation, it must keep a non-reentrant request gate so another `advance` call cannot interleave. Cross-runtime rendering or encoding pressure belongs between separate advance requests, not inside a partially coordinated batch.

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

## Input Must Be Attributable to Ticks

Current ``InputSnapshot`` semantics are useful across several configurations: held state persists, and cumulative pointer/scroll totals let Simulation derive motion across skipped publisher revisions. An MCP adapter can initially submit the same `InputEvent` values as the platform adapter and then request a tick.

That is not the only control boundary Engine2 will ever need. Three levels should remain distinct:

1. raw host ingress such as keyboard, pointer, controller, or text callbacks
2. revisioned device state published by an Input Runtime
3. tick-addressed player actions or game-semantic commands accepted at the Simulation boundary

MCP, bots, replays, network peers, and tests may eventually prefer semantic commands rather than impersonating a keyboard. Do not expand physical `InputEvent` into a universal command bag to serve those uses.

Batch advancement must define its input behavior. “Apply this input and advance 30 ticks” is ambiguous unless the contract states whether a transition occurs once, held state persists, an action repeats every tick, or a distinct per-tick control schedule is supplied. One-step requests are the unambiguous baseline; an optimized batch should carry explicit input scheduling semantics.

If several input producers control one session, an App-owned input arbiter must define source/player identity, merge rules, priority, and publication revision. Publisher-local revisions cannot be naively merged by choosing whichever snapshot arrived last.

## There Is At Most One Effective Advance Authority

At most one effective authority may issue progress requests for a Simulation session, and exactly one must be active whenever progress is permitted. Actor serialization alone is not sufficient: two logically independent drivers can still create nondeterministic ordering even if their calls never overlap.

A development assembly can expose real-time, manual-step, and MCP controls together only if one coordinator arbitrates them. For example, it may suspend real-time demand while an MCP transaction owns a temporary manual-step lease, then explicitly rebase wall-clock timing before resuming.

This also clarifies pause:

- pausing the advance authority normally means no new simulation ticks occur
- stopping a Runtime is a lifecycle operation
- disabling a subset of gameplay systems is a separate Simulation execution mode, if that capability is deliberately retained
- rendering, inspection, encoding, input collection, and other peer-runtime work may continue while Simulation is paused

Every pause policy must also state what happens to input revisions accumulated while no ticks occur. A configuration may ingest them on resume, rebase and discard transient totals, neutralize controls, or journal tick-addressed transitions. Rebasing wall-clock time alone does not resolve accumulated input.

The current `pauseSimulation()` leaves ``SimulationLoop`` active, runs always systems, and advances tick identity while simulation-gated systems are disabled. That behavior may remain useful as a specially named mode, but it should not define universal pause semantics for deterministic offline, replay, test, or MCP configurations.

## Publications and Exact Results Serve Different Work

Engine2 needs several explicit boundary shapes rather than one universal bus:

| Boundary | Semantics | Typical use |
| --- | --- | --- |
| Latest snapshot | Newest completed value replaces older values | Onscreen rendering, slow displays, dashboards |
| Ordered event lane | Per-publisher order with explicit buffer/drop policy | Audio occurrences, achievements, recorders |
| Exact request/result | Caller awaits a value correlated to its command | Simulation advance, offscreen render, MCP response |
| Durable journal | Explicit retained history and cursoring | Replay, auditing, rollback, time travel |

``PSimulationPresentationSource`` is intentionally a latest-value boundary. That is correct for a display renderer that can skip superseded states. It is insufficient by itself for an offline frame job or an MCP operation that must render exactly the state produced by its own advance request.

An exact workflow must receive or retain the immutable snapshot associated with the completed cursor. It must not advance, read `latestPresentationSnapshot` after an unrelated caller has changed it, and silently render the wrong state.

Likewise, a multi-tick advance must not imply that events from intermediate ticks are safely recoverable from the final snapshot. A workflow that needs every occurrence must use an ordered lane or explicit journal with a result cursor.

Backpressure belongs to each connection:

- a real-time display normally drops superseded snapshots rather than stalling Simulation
- an archival offline renderer intentionally prevents the coordinator from requesting the next required tick until the exact frame is safe
- a cloud video stream may drop stale encoded frames to protect latency
- a replay recorder may fail or stop advancement rather than lose required history
- an MCP operation may bound work, return partial completed progress, and allow a later request to continue

No connection may suspend the executor halfway through a world mutation. Pressure is applied after a completed tick and before the next request.

## Realtime Interactive Configuration

The current application is the first configuration, not the universal application shape:

```text
AppKit adapters ---> InputRuntime ---> latest InputSnapshot
                                           |
monotonic clock ---> RealtimeAdvanceDriver-+
                                           |
                                           v
                                  SimulationRuntime
                                           |
                          latest presentation snapshot
                                           |
                                           v
                                  ScreenRenderRuntime
```

The real-time driver owns:

- clock sampling
- elapsed-time remainder
- catch-up and maximum-step policy
- backlog overflow policy
- sampling or assigning input at advance boundaries
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
             +-- render(snapshot, settings) -------> OffscreenRenderRuntime
             <-- rendered output -------------------+
             |
             +-- encode / write -------------------> ArtifactSink
             <-- completion -------------------------+
             |
             +-- serial policy may permit the next required step
```

The coordinator can hold Simulation at one cursor while Render:

- accumulates thousands of samples
- renders tiles or several cameras
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
      +-- render(snapshot, settings) ------------> OffscreenRenderRuntime
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
- artifact metadata containing at least the Simulation cursor and render settings identity

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
| Photo mode | No active Simulation advancement | Render one frozen snapshot with many cameras, exposures, or quality levels |
| Multi-window live play | Real-time driver | Primary view, minimap, spectator, recorder, and telemetry consume independent outputs |
| AR or VR | Real-time driver | Simulation remains fixed-step; Render owns late pose and presentation prediction |

### Offline, Batch, and Content Work

| Configuration | Advance authority | Notable topology |
| --- | --- | --- |
| Cinematic capture | Offline output timeline | Exact snapshots, path tracing, image sequence or video encoding |
| Multi-camera capture | Offline coordinator | One Simulation cursor feeds many camera renders before the next step |
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
| Spectator/replay client | Network or replay timeline | No local player control; presentation can pause, delay, or scrub |
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
- a connection crosses an actor, process, or transport boundary with values that cannot safely cross it
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

The project can initially coordinate configurations on the main actor. Parallel batch sessions, worker rendering, or an out-of-process MCP host will eventually require:

- immutable boundary values that explicitly conform to `Sendable`
- serialization or `Codable` contracts where values cross processes
- one isolated executor for each authoritative Simulation session
- no `await` inside the mutation of one tick
- bounded batches so one session cannot monopolize an executor
- cancellation between ticks, never during partial world mutation
- GPU completion and encoding isolated inside Render/Capture ownership

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
| ``Engine/step(inputSnapshot:)`` | Existing exact one-step execution seam |
| ``Engine/update(deltaTime:inputSnapshot:)`` | Current real-time remainder and catch-up policy; candidate to move behind the real-time driver |
| ``SimulationLoop`` | Current wall-clock cadence adapter; candidate to become configuration/App-owned rather than Simulation-owned |
| ``SimulationRuntime`` | Correct owner of session construction, authoritative state, step serialization, and completed publications; currently hard-wires the real-time driver |
| ``InputRuntime`` | Replaceable physical-input owner with narrow ingress and latest-snapshot capabilities |
| ``SimulationPresentationSnapshot`` | Existing immutable publisher-owned presentation surface |
| `PSimulationPresentationSource` | Existing latest-value live boundary, suitable for droppable consumers |
| ``RenderFrame`` | Existing Render-owned private projection with source-tick attribution |
| `MetalRenderer` and `MetalSceneView` | Current screen-oriented rendering path; view ownership and drawable cadence still need extraction for a full Render Runtime |
| Render integration test support | Evidence that explicit offscreen textures and GPU submission are practical, though production artifact readback/encoding remains absent |

The most important current gaps are:

- ``SimulationRuntime`` always constructs a concrete ``SimulationLoop``
- the Runtime retains one input source instead of receiving explicit tick-boundary control through an advance request
- direct ``Engine/step(inputSnapshot:)`` does not automatically update Runtime publications according to their declared semantics
- `SimulationRuntime.engine` is internally visible and `SimulationRuntime.world` exposes the live mutable world; current App tooling such as input-history and entity-motion panes uses that escape instead of deliberate inspection capabilities
- `start`, `stop`, `resumeSimulation`, and `pauseSimulation` combine lifecycle, driver, and schedule-gating concerns
- ``Engine/update(deltaTime:inputSnapshot:)`` contains unbounded real-time catch-up policy
- latest presentation publication can skip intermediate ticks and cannot guarantee an exact offline/MCP result by itself
- ``SimulationTick`` is not qualified by a Simulation session identity
- there is no production view-independent `RenderRuntime`, offscreen request API, image artifact contract, or JPEG encoder
- ordered Simulation events, input transitions, checkpoints, and journals remain proposed
- many cross-runtime values and capabilities remain main-actor-bound rather than explicitly `Sendable`

None of these gaps require weakening ECS authority or introducing backend objects into ``World``.

## Incremental Implementation Path

### 1. Establish Session-Qualified Identity

Add a Simulation session/epoch identity and pair it with ``SimulationTick``. Propagate the cursor through presentation snapshots, render attribution, advance results, and eventually events and artifacts.

### 2. Add a Runtime-Level Exact Advance Capability

Make ``SimulationRuntime`` the only application/configuration integration boundary that calls ``Engine/step(inputSnapshot:)``. Direct calls remain valid inside Simulation implementation and focused ``Engine`` unit tests. The Runtime should serialize the request, complete full ticks, update snapshots and events according to each lane's declared semantics, and return an exact correlated result.

Replace App-tooling access to the live `world` with deliberate read or inspection snapshots before making the Runtime boundary inaccessible. UI and MCP inspection must not become alternate mutation paths.

### 3. Extract the Realtime Driver Without Changing Behavior

Move ``SimulationLoop`` ownership into the App's first concrete Runtime Assembly. Move elapsed-time remainder, catch-up cap, and overload policy out of the deterministic Simulation core. Rebuild today's app as `RealtimeConfiguration` and prove parity with existing tests.

### 4. Make Pause an Advancement Policy

Stop issuing ticks while ordinarily paused. If always-running tool/input stages remain necessary, give that operation and its tick semantics an explicit name rather than conflating it with a frozen simulation.

### 5. Prove a Manual Configuration

Add a tiny deterministic assembly that can advance exactly one or N ticks without a polling task. This is the cheapest proof that Simulation is no longer tied to real time and is a foundation for tests, replay, offline work, and MCP.

### 6. Create a View-Independent Render Runtime Boundary

Separate render resource ownership and explicit-frame encoding from `MTKViewDelegate` and SwiftUI view lifetime. Preserve the existing view adapter for screen presentation.

### 7. Add Production Offscreen Request/Result Rendering

Accept an exact immutable presentation value plus explicit target/quality settings, await GPU completion, read back, encode, and return an artifact labeled with its Simulation cursor. Reuse current backend passes where practical.

### 8. Add Offline Render-Gated Coordination

Map an output timeline to exact Simulation cursors, render one or more outputs per cursor, and apply the configuration's declared serial or bounded-pipeline backpressure policy.

### 9. Add MCP Coordination

Start with physical input emulation if useful, then add semantic control deliberately. Serialize commands, enforce expected cursors and idempotency, bound steps, expose structured observations, and return exact image artifacts.

### 10. Add History Only for Concrete Needs

Introduce event lanes, checkpoints, journals, rollback, and time travel when their configurations require them. Do not burden ordinary latest-value real-time connections with durable history by default.

## Verification Required During Migration

Tests for this direction should prove:

- a Runtime-level manual step advances exactly once and publishes/returns the exact completed cursor
- no application/configuration path can mutate the Engine while bypassing Runtime publication invariants; focused Engine tests remain valid
- extracted real-time driving preserves current fixed-step and input behavior
- pause causes no cursor change unless an explicitly named alternate execution mode is requested
- input revisions and transient totals are consumed exactly once across one-step and batched requests
- a world rebuild produces a new session-qualified cursor
- stale expected-cursor and duplicate MCP requests cannot double-advance
- cancellation reports only fully completed ticks
- offline Render receives the exact requested immutable snapshot even if rendering is slow
- one snapshot can render many cameras or samples without re-running Simulation
- configuration startup, partial failure, and reverse-order shutdown are deterministic
- multiple assemblies have no global mutable-state contamination
- offscreen artifacts preserve cursor, render settings, and content identity needed for attribution
- each event or publication connection obeys its declared backpressure and retention policy

## Architectural Traps

Avoid:

- creating a `TickRuntime` that owns Simulation's fixed delta or tick counter
- using an ECS `S` type for top-level cadence or configuration work
- letting a Render Runtime, MCP Runtime, Network Runtime, or view call ``Engine`` or mutate ``World``
- exposing elapsed `deltaTime` as the only portable advancement API
- allowing several drivers to race and relying on actor serialization to make the order meaningful
- assuming one render frame equals one simulation tick
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

## Open Design Questions

The following details should remain open until the first vertical slices provide evidence:

- the exact names and sync/async shape of the Simulation advance protocol
- whether every one-step result directly carries the presentation snapshot or uses an exact cursor-addressed rendezvous
- the optimized representation of per-tick input/control batches
- how long exact snapshots are retained for render retries and remote requests
- whether the real-time driver is an ordinary App-owned coordinator or earns a Runtime boundary
- how actor isolation evolves beyond the current main-actor implementation
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
