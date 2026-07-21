# Instrumentation and Diagnostics

This article proposes an observability architecture for understanding Engine2 performance, diagnosing failures, and tracking the cost of architectural growth.

## Status

Proposed future work.

The current app has useful debug surfaces, including input history, render output modes, and a retained terminal render error. It does not yet have a shared telemetry vocabulary, signposts, structured runtime logs, repeatable performance scenarios, or machine-readable diagnostic bundles.

## Goals

Engine2 diagnostics should make it possible to answer four questions:

1. Which runtime or system consumed the time?
2. Was that time expected for the amount of work performed?
3. Did independent Input, Simulation, and Render cadences remain healthy?
4. Did a change make the app more complex, more expensive, or harder to explain?

The resulting evidence should be useful in Instruments, in an in-app debug visualization, in tests, and to Codex through stable text and JSON artifacts. Capturing diagnostics must not change runtime correctness, introduce a global mutable service locator, or make an optional diagnostic consumer part of a publisher's correctness.

## Design Principles

### Keep Three Complementary Planes

Use three observability planes, each optimized for a different job:

| Plane | Primary tool | Purpose |
| --- | --- | --- |
| Trace | `OSSignposter` and Instruments | Duration, overlap, cadence, and causal timing |
| Semantic record | `Logger` and unified logging | Lifecycle changes, unusual paths, failures, and context |
| Diagnostic model | Typed, bounded samples | Debug visualizations, deterministic exports, comparisons, and test assertions |

No one plane should imitate all the others. Logs are not a reliable event journal or a high-frequency metrics database. Signposts are not a substitute for an error description. The in-memory diagnostic model should not attempt to reproduce Time Profiler, Metal System Trace, or the system log.

The same instrumentation call may emit to the system trace and append a small typed sample, but the typed sample remains the primary machine-readable data. This avoids making Codex parse presentation text to recover numeric metrics.

### Preserve Runtime Ownership

Each runtime should describe work that occurs within its own authority:

- Input reports host-event ingestion and snapshot publication.
- Simulation reports polling, fixed steps, system execution, backlog, and snapshot capture.
- Render reports snapshot projection, frame-slot pressure, encoding, submission, GPU completion, and resource resolution.
- The App reports lifecycle wiring and scenario identity.

An optional App-owned `DiagnosticsRuntime` becomes worthwhile when recording, visualization, and export need their own lifecycle and bounded retained state. The App may inject a narrow diagnostic sink while constructing each runtime. A no-op sink preserves identical runtime wiring when diagnostics are disabled.

```text
InputRuntime ---------+
                      |
SimulationRuntime ----+--> optional DiagnosticsRuntime --> DiagnosticsSnapshot
                      |                                  +-> NDJSON export
Render responsibilities+                                  +-> debug dashboard

Each owner -----------> Logger / OSSignposter -----------> unified log / Instruments
```

`DiagnosticsRuntime` must consume reported values. It must not discover runtimes globally, read live `World` storage, or reach into `MetalResourceStore`. A runtime that has no diagnostic consumer must remain correct. Static `Logger` and `OSSignposter` values are immutable handles into Apple system facilities, not a process-global mutable Engine2 resource.

Do not introduce the runtime merely to hold helper functions. Before recording or visualization exists, runtime-local instrumentation values are sufficient.

### Use Stable, Low-Cardinality Vocabulary

Use the bundle's reverse-DNS identity, currently `com.example.Engine2`, as the logging subsystem. Centralize a finite set of category identifiers rather than scattering string literals:

- `app.lifecycle`
- `input.runtime`
- `simulation.loop`
- `simulation.system`
- `simulation.snapshot`
- `render.frame`
- `render.asset`
- `render.gpu`
- `diagnostics.capture`

Signpost names are stable static strings. Dynamic identity belongs in signpost messages and typed samples, not in newly generated categories or signpost names. This keeps Instruments tracks, `XCTOSSignpostMetric`, predicates, and export parsers stable as the code changes.

Use domain types or closed enums for known identifiers such as runtime, invariant system, render pass, output mode, and sample kind. Do not replace a closed vocabulary with raw strings. If future consumer-defined systems require open identifiers, introduce a string-backed system identifier only at that extension boundary and document why the vocabulary is open-ended.

### Correlate Without Inventing a Universal Frame

There is no universal application frame. Preserve the identities each owner already understands:

- diagnostic capture session
- Input Runtime session and revision
- ``SimulationTick``
- render frame sequence
- source simulation tick carried by ``RenderFrame``
- Metal submission sequence

Use a unique signpost ID for overlapping invocations. Begin and end an interval with the interval state returned by `OSSignposter`; retain that state across asynchronous work when necessary. Use the exclusive signpost ID only when overlap is impossible by construction.

Do not stretch one interval across peer-runtime ownership. For example, Simulation snapshot publication and Render projection are two intervals correlated by source tick, not one interval that makes Simulation wait for an optional Render consumer.

## Signpost Plan

Apple recommends signposted intervals for measured tasks and events for notable points in time. The first instrumentation pass should use the following stable names:

| Category | Signpost | Kind | Scope and useful dimensions |
| --- | --- | --- | --- |
| `input.runtime` | `InputReceive` | event | input revision and closed event kind; sampled if event volume becomes high |
| `input.runtime` | `InputSnapshotPublish` | event | session, revision, held-key count, held-button count |
| `simulation.loop` | `SimulationPoll` | interval | sampled wall delta, steps completed, backlog before and after |
| `simulation.loop` | `SimulationStep` | interval | tick and whether simulation-gated systems ran |
| `simulation.system` | `SystemUpdate` | interval | stable system identifier, schedule lane, tick, entity/work count when meaningful |
| `simulation.snapshot` | `PresentationSnapshotCapture` | interval | tick and published entity count |
| `render.frame` | `RenderFrameCPU` | interval | frame sequence, source tick, output mode, projected and submitted instance counts |
| `render.frame` | `FrameSlotWait` | interval | frame slot and in-flight count |
| `render.frame` | `RenderProjection` | interval | source tick, published count, accepted count, rejected count |
| `render.frame` | `FrameEncode` | interval | render pass count, draw count, submesh count, instance count |
| `render.gpu` | `GPUFrame` | interval | submission sequence, frame sequence, source tick, feedback result |
| `render.asset` | `AssetLoad` | interval | closed mesh identity and resulting mesh/submesh counts |
| `render.asset` | `PipelineCompile` | interval | closed pipeline identity; construction-time only |

The outer intervals explain cadence. Nested intervals explain where the outer time went. Start with these coarse boundaries and add a deeper interval only after an unexplained cost appears. Per-entity signposts and signposts inside component-row loops would create excessive volume and distort the work being measured.

Guard any expensive diagnostic payload construction with the signpost's enabled state. Messages should contain small scalar values and stable identifiers, not arrays, component dumps, model descriptions, or arbitrary object interpolation.

The `GPUFrame` interval begins immediately before queue commit and ends from Metal feedback. It measures submission lifetime, not pure shader-core execution. Instruments Metal tracks and GPU counters remain authoritative for determining whether shader, bandwidth, synchronization, CPU submission, or display pacing is the limiting factor.

## Logging Plan

Use `Logger` for semantic facts that remain valuable when no trace recording is active. Every message should have a stable event name and a compact field grammar, for example:

```text
event=simulation_backlog_high session=8 tick=421 steps=4 backlog_ns=52000000
```

The unified log's NDJSON already carries timestamp, process, subsystem, category, level, and signpost metadata. The event message only needs domain fields that are not already present.

Choose levels deliberately:

| Level | Engine2 use |
| --- | --- |
| Debug | High-volume development facts that are useful only during an active investigation |
| Info | Capture/scenario boundaries and ordinary lifecycle context included when explicitly collected |
| Notice | Unusual but handled states, threshold crossings, and meaningful mode changes |
| Error | Failed work with a preserved error, such as render preparation or submission failure |
| Fault | Violated invariants or an app state that indicates a programming defect |

Do not log every fixed step or draw at notice or above. Signposts and bounded samples already describe those paths. Avoid duplicate “started” and “finished” log messages around every signposted interval.

Dynamic strings and objects are private by default in unified logging. Explicitly mark only an allowlist of non-user data as public: closed engine identifiers, counts, durations, revisions, ticks, error-domain identifiers, and generated diagnostic session IDs. Do not emit paths, input text, arbitrary asset metadata, or future player/content data as public. Privacy is part of the schema, not a decision left to each call site.

Unified logging is subject to level-dependent persistence, storage limits, privacy redaction, and loss. It must not become authoritative gameplay history, replay storage, or a correctness-sensitive runtime event lane.

## Typed Diagnostic Model

An in-memory model provides repeatable data for visualizations and Codex. Proposed boundary values are:

- `DiagnosticsSessionID`: identifies one capture and never affects simulation identity.
- `DiagnosticsSample`: a timestamped enum with one typed payload per sample kind.
- `DiagnosticsSnapshot`: an immutable latest value containing bounded aggregates and recent samples.
- `DiagnosticsManifest`: environment, scenario, source revision, configuration, and schema information.

Store a short bounded ring, initially 15 to 30 seconds, and rolling aggregates. Never retain an unbounded sample array. The diagnostic clock is monotonic and observational; it is not simulation time.

Every duration must include its unit in the property name, preferably nanoseconds in raw artifacts. Every quantity needs an explicit semantic name, such as `backlogNanoseconds`, `submittedInstanceCount`, or `sourceTickAge`. Avoid ambiguous fields such as `time`, `size`, or `count`.

### Measure Cost and Scale Together

Duration without work volume becomes misleading as the engine grows. Record the numerator and denominator separately, then derive normalized rates in the report rather than in hot code.

Useful initial samples include:

| Area | Cost samples | Scale and health samples |
| --- | --- | --- |
| Input | receive-to-publish duration | events per second, revision sampled by Simulation, held input counts |
| Simulation loop | poll and step duration | wall delta, steps per poll, accumulated backlog, skipped wake deadlines |
| Systems | duration by stable system ID | matching dense-row or joined-entity count where meaningful |
| Snapshot boundary | capture duration | renderable rows and published presentations |
| Render projection | projection duration | published, accepted, rejected, and truncated instance counts |
| Render CPU | slot-wait, preparation, encode, and submit durations | frame sequence, source tick age, draw and submesh counts, missing drawable count |
| Render GPU | submission lifetime and feedback status | in-flight submissions and presentation cadence |
| Resources | load and compile durations | models, meshes, pipelines, argument tables, frame slots, cache hits and misses |

Report distributions, including p50, p95, p99, and maximum, rather than only averages. Preserve sample count and warm-up policy beside each distribution.

### Track Structural Complexity Explicitly

At app construction and world rebuild, record a low-frequency inventory:

- ordered always-running and simulation-gated system identifiers
- component-store row counts under each store's stable diagnostic identity
- presentation entity count
- authored mesh and material counts
- render pipeline, pass, model, and frame-resource counts
- maximum and observed instances, draws, and submeshes per frame
- diagnostic schema version and enabled feature set

This inventory distinguishes “the same work became slower” from “the change added more work.” It also makes architecture growth visible in review. Registration should produce the inventory; a source-regex script should not attempt to infer runtime behavior.

A component store's diagnostic identity is reporting metadata only. It must not become a closed component registry, a storage key, or a condition for adding consumer-defined component types.

The highest-value comparisons pair structural change with runtime cost. Examples include:

- a new invariant system plus its p95 contribution to `SimulationStep`
- a new component row population plus the systems that scan it
- a new render pass or pipeline plus CPU encode and GPU-frame changes
- increased snapshot population plus capture and projection cost
- a new asset identity plus load time and retained backend-resource counts

## Debug Visualizations

Add a diagnostics command beside the current input-history and render-output controls. The UI consumes only an immutable `DiagnosticsSnapshot`; it must not sample live `World` or renderer internals.

### Compact HUD

The compact overlay should answer “is the app healthy right now?” without obscuring the scene:

- simulation state, current tick, and fixed-step target
- recent poll rate, steps per poll, and backlog
- render rate, source tick age, and frames in flight
- CPU frame p50/p95 and GPU submission-lifetime p50/p95
- instance and draw counts
- latest notice, error, or fault indicator

Refresh the HUD at a modest independent cadence, such as 5 to 10 Hz. Rendering the debug UI at every input event or diagnostic sample would make the observer part of the performance problem.

### Expanded Dashboard

The expanded view should provide a bounded, pausable timeline with:

1. Input revision, Simulation poll/tick, Render frame, and GPU submission lanes.
2. A stacked system-duration chart for each `SimulationStep`.
3. Backlog, steps-per-poll, and snapshot-freshness graphs.
4. A presentation funnel: ECS renderable rows → snapshot entities → projected instances → submitted instances → draws.
5. Render CPU phase and in-flight-slot pressure charts.
6. Resource inventory, cache activity, and error history tables.

Allow pause, scrub, reset, and export. Give every chart a textual table or summary so a screenshot is never the only evidence. Stable accessibility identifiers make UI automation and Codex-driven screenshot capture repeatable.

The dashboard is a debug presentation owned by the App. It is not a new source of simulation truth. Existing views such as `InputHistoryPane` should eventually consume purpose-built debug snapshots rather than reading `simulation.world` directly, preserving the same inspection boundary.

## Repeatable Codex Capture

Create one repository-owned entry point with a stable command surface. The spelling below is proposed; the contract matters more than the implementation language.

```text
./Tools/diagnostics capture --scenario baseline-six-ball --duration 15s --configuration Release
./Tools/diagnostics summarize .build/diagnostics/<capture-id>
./Tools/diagnostics compare <baseline-capture> <candidate-capture>
```

The capture command should:

1. Build through the project-aware Xcode workflow.
2. Launch a named deterministic scenario with a fixed seed and explicit warm-up and measurement windows.
3. Record an Instruments trace using a checked-in template.
4. Collect the matching unified-log window by subsystem.
5. Request the app's typed diagnostic export.
6. Export selected trace tables and produce summaries.
7. Validate that required artifacts exist and conform to their schema.

Use at least two scenario classes:

- deterministic CPU scenarios that directly advance a known world for a fixed tick count
- integration scenarios that exercise the real app loop, presentation path, drawable acquisition, and GPU submission for a fixed wall duration

Begin with the existing deterministic six-Ball scene. Add scale scenarios only when the world builder can produce them deliberately, for example 100, 1,000, and 10,000 quiescent renderables with fixed authored identities. An input script should use explicit `InputEvent` values and a fixed schedule rather than synthesized human input.

Engine2 is sandboxed, so the capture design must not grant the app broad write access to the repository. In automated scenario mode, encode typed samples to standard output and let the outer runner redirect that stream to `diagnostics.ndjson`; `xctrace record` supports target-standard-output redirection for launched processes. A future interactive export can use an App-owned user-selected destination. In both cases, the capture runner—not a runtime—owns the artifact directory.

### Artifact Bundle

Each capture should produce one self-contained directory:

```text
capture-id/
├── manifest.json
├── diagnostics.ndjson
├── summary.json
├── summary.md
├── unified-log.logarchive
├── unified-log.ndjson
├── instruments.trace
├── trace-toc.xml
├── trace-signposts.xml
├── dashboard.png
└── result.xcresult
```

Not every scenario needs every optional file, but the manifest must state which artifacts were requested, produced, skipped, or failed.

`manifest.json` records at least:

- artifact schema version
- Git revision and dirty-worktree state
- scenario identity and scenario schema version
- build configuration and compiler/Xcode version
- operating system, hardware model, CPU, GPU, memory, and display characteristics
- app version and bundle identifier
- diagnostic feature flags
- warm-up and measurement durations
- fixed step, render output mode, random seed, and content inventory

Raw numeric data goes in `diagnostics.ndjson`. `summary.json` contains distributions, deltas, threshold results, and links to supporting sample kinds. `summary.md` is a concise human and Codex orientation report generated entirely from `summary.json`.

Do not commit large captures or `.trace` bundles. Commit scenario definitions, schemas, summarizers, budgets, and small reviewed baseline summaries. Store or attach full captures only when they support a specific investigation.

### Unified Log Export

The installed macOS logging tools support exact archive and newline-delimited JSON forms. The capture implementation should use equivalent commands with shell-safe resolved paths:

```text
/usr/bin/log collect --last 30s --output <capture>/unified-log.logarchive
/usr/bin/log show \
  --archive <capture>/unified-log.logarchive \
  --style ndjson \
  --info --debug --signpost \
  --predicate 'subsystem == "com.example.Engine2"'
```

Prefer a timestamped start boundary plus a small margin over an arbitrarily large `--last` window. Preserve the archive as forensic source data and the filtered NDJSON as the normal Codex input. The summary should report log-loss entries and redacted fields rather than silently treating the export as complete.

### Instruments Export

Keep the native `.trace` for visual inspection. Make it useful to automation by exporting its table of contents and selected schemas:

```text
xcrun xctrace export --input <capture>/instruments.trace --toc --output <capture>/trace-toc.xml
xcrun xctrace export --input <capture>/instruments.trace --xpath <known-table-query> --output <capture>/trace-signposts.xml
```

`xctrace` table schemas can vary with tool and template versions. The summarizer should inspect the table of contents, accept only known schema versions, and fail with an explanatory result when an Xcode update changes them. It must not produce a plausible empty report from an unrecognized trace.

Use an os-signpost/Time Profiler template first and a Metal System Trace or Game Performance template for render investigations. A custom Instrument becomes appropriate only when ordinary signpost tracks can no longer express a repeated analysis; Apple explicitly recommends considering one for complex, high-volume signpost data.

### Comparison Rules

Compare captures only when the manifest says their environment and scenario are compatible. GPU and display metrics are hardware-specific. CPU measurements can also shift across power, thermal, debugger, sanitizer, and build-configuration states.

Use a Release performance configuration with the debugger, code coverage, and sanitizers disabled for regression captures. Preserve Debug captures for rich investigation, but do not compare them to Release baselines.

The comparison command should exit nonzero for an incompatible comparison, missing evidence, correctness failure, or exceeded approved budget. It should distinguish those outcomes from an ordinary performance delta.

Codex should be able to follow this fixed investigation loop:

1. Read `manifest.json` and compatibility results.
2. Read `summary.md` for orientation and `summary.json` for exact values.
3. Identify the first regressed outer interval or structural count.
4. Inspect its nested system, snapshot, render, or resource samples.
5. Filter `unified-log.ndjson` by session and correlation identity for semantic context.
6. Inspect exported trace tables or the native trace only where sampled evidence points.
7. Re-run the same scenario and compare the new capture.

## Regression Tests and Budgets

XCTest remains the supported performance-test surface even though most current behavior tests use Swift Testing. Add focused XCTest performance cases where a stable workload exists.

Initial tests should cover:

- a fixed count of `Engine.step()` calls for the baseline world
- each invariant system with a representative component population
- `SimulationPresentationSnapshot.capture(from:at:)` at several scales
- `RenderFrame.project(from:)` at several scales, including rejected transforms
- Render resource-store construction and model loading on known supported hardware
- selected app-level signposts through `XCTOSSignpostMetric`

Record wall time together with `XCTCPUMetric` and `XCTMemoryMetric` where they answer a specific risk. Set baselines only after collecting enough stable runs on the intended machine class. Do not begin with arbitrary hard thresholds that merely encode one noisy measurement.

Keep correctness gates separate from statistical budgets. The following are failures regardless of performance baseline:

- a terminal render error
- nonfinite presentation or render data reaching submission
- an unbalanced required interval
- an unexpected scenario inventory
- missing diagnostic samples or an unrecognized artifact schema

Once observations are stable, add reviewed budgets for p95 fixed-step duration, backlog, source-tick age, frame-slot wait, snapshot projection, and relevant memory/resource counts. Every budget should name its scenario, environment class, rationale, owner, and last review date.

## Field Evidence

MetricKit complements local captures with delayed evidence from real use. It does not replace deterministic scenarios because reports are aggregated, environment-dependent, and delivered later.

When Engine2 is ready to collect field evidence:

- retain one long-lived metric manager at the App boundary
- archive its Codable reports in a versioned JSON envelope that Codex can inspect
- use a small number of stable state-reporting domains, such as gameplay state and render output configuration
- avoid entity, session, asset-instance, or level-instance values that create high cardinality
- use MetricKit signpost APIs only for a few user-meaningful intervals whose CPU, memory, write, or hitch distributions matter in production
- handle unknown future metric cases and state-limit overflow explicitly

The first likely field intervals are extended app readiness, active simulation, and visible frame presentation. Per-system MetricKit signposts would be too implementation-specific and numerous; local diagnostics remain the better surface for that detail.

## Rollout as Committable Changes

The rollout should be an ordered series of small commits, not four feature branches that land all at once. Every commit below has one primary concern, includes its own tests or fixture validation, and leaves the app buildable. Land the numbered commits in dependency order; a later slice must not be needed to make an earlier slice complete. Later commits may refine an earlier diagnostic schema, but must version that change in the same commit.

The first implementation track prioritizes Simulation because fixed-step overload policy is a known gap and system-count growth is the clearest near-term complexity risk. Render instrumentation follows only after capture and comparison are useful enough to consume it.

### Commit 0: Record the Architecture

**Suggested commit:** `docs: propose repeatable app instrumentation`

- Add this article and link it from the DocC catalog.
- Make no production-code or build-setting changes.
- Verify with a DocC build and record any pre-existing documentation warnings separately.

This documentation change is the reviewable contract for the implementation commits below.

### Commit 1: Add the Typed Diagnostics Boundary

**Suggested commit:** `feat(diagnostics): add typed sample boundary`

- Add the smallest stable vocabulary needed by Simulation: diagnostic session identity, monotonic timestamp, category, sample envelope, and sample payloads.
- Add a narrow sink protocol plus a no-op implementation.
- Keep the types observational; none may be used as simulation identity or state.
- Add unit tests for equality, ordering where defined, no-op behavior, and Codable round trips for values intended to leave the process.

Do not wire a runtime or add UI in this commit. The app should behave exactly as it did before.

### Commit 2: Add the OS Emission Facade

**Suggested commit:** `feat(diagnostics): add signpost and log emission`

- Add centralized mappings from typed categories and event names to static `Logger` and `OSSignposter` handles.
- Add one small emitter that can write to Apple system facilities and the optional typed sink.
- Encode the public-data allowlist and enabled-state guards in this layer.
- Test the identifier mappings and typed-sink forwarding without asserting against the machine's unified log store.

No hot runtime path changes in this commit. This isolates Apple API usage and privacy policy from the later measurement sites.

### Commit 3: Instrument Engine Steps and Systems

**Suggested commit:** `feat(simulation): instrument fixed steps and systems`

- Inject the diagnostics emitter into ``Engine``, defaulting to the no-op path.
- Add `SimulationStep` and `SystemUpdate` intervals.
- Add stable identities for the current invariant systems and record their schedule lane and execution order.
- Record a work count only where the system can obtain it without an additional component-store scan.
- Extend `EngineTests` with a recording sink that verifies interval order, tick correlation, schedule identity, and unchanged world results.

This is the first production instrumentation commit and should not modify loop polling, input, snapshot capture, or rendering.

### Commit 4: Report Polling and Backlog

**Suggested commit:** `feat(simulation): report loop cadence and backlog`

- Add `SimulationPoll` around one ``SimulationLoop`` update.
- Report sampled wall delta, steps completed, and accumulated backlog before and after the poll.
- Log loop start, stop, cancellation, and an explicitly selected backlog threshold crossing.
- Extend `SimulationLoopTests` with injected clock and sleeper fixtures that produce zero-step, one-step, and catch-up polls deterministically.

Do not add an overload clamp in this commit. Instrument the existing behavior first so a later overload-policy change has before-and-after evidence and remains its own behavioral commit.

### Commit 5: Report Presentation Capture

**Suggested commit:** `feat(simulation): report presentation capture`

- Measure `SimulationPresentationSnapshot.capture(from:at:)` at the ``SimulationRuntime`` publication site.
- Report tick, renderable-row count, and published-presentation count without performing a second row scan.
- Extend `SimulationRuntimeTests` and snapshot tests with exact publication expectations.

This commit stops at the Simulation-owned boundary. It does not add Render projection metrics.

### Commit 6: Record Runtime Inventory

**Suggested commit:** `feat(simulation): report runtime inventory`

- Emit the ordered system and component-store inventory at world construction and rebuild.
- Report presentation entity count separately from component-store representation.
- Keep component diagnostic identities as reporting metadata, never as a registry or storage key.
- Extend `EngineTests`, `WorldTests`, and world-builder tests with exact inventory and rebuild expectations.

This low-frequency structural record is separate from timing so a storage-vocabulary change can be reviewed without touching hot paths.

### Commit 7: Report Input Publication

**Suggested commit:** `feat(input): report event ingestion and snapshots`

- Add a closed diagnostic identity for the current `InputEvent` cases.
- Emit sampled `InputReceive` events and `InputSnapshotPublish` facts with session, revision, and held-state counts.
- Make the sampling rule explicit and deterministic when high-frequency motion events are reduced.
- Extend `InputRuntimeTests` to prove diagnostics do not change revision, cumulative-motion, or neutral-state semantics.

Input is a separate commit because its host-event cadence and privacy risks differ from fixed-step Simulation work.

### Commit 8: Add the Bounded Diagnostics Runtime

**Suggested commit:** `feat(diagnostics): retain bounded runtime samples`

- Add `DiagnosticsRuntime` now that recording has concrete lifecycle and state value.
- Implement the bounded recent-sample ring and rolling aggregates for the sample kinds added so far.
- Publish an immutable `DiagnosticsSnapshot` without exposing the mutable recorder.
- Wire Input and Simulation sinks at the App composition root.
- Add tests for capacity, eviction, reset, aggregate correctness, disabled collection, and runtime deallocation.

No debug UI or filesystem export belongs in this commit. The new runtime should be invisible in normal presentation.

### Commit 9: Define and Encode the Artifact Schema

**Suggested commit:** `feat(diagnostics): encode versioned capture artifacts`

- Add versioned `DiagnosticsManifest`, diagnostic NDJSON records, and summary input types.
- Add a streaming encoder that can write scenario output to standard output without requiring repository filesystem access from the sandboxed app.
- Add small checked-in golden fixtures and round-trip, unknown-version, truncated-stream, and unit-field tests.
- Document the schema beside the types.

Do not add process launching, unified-log capture, Instruments, or statistics yet. This commit defines the stable machine-readable contract those tools consume.

### Commit 10: Add the Baseline App Scenario

**Suggested commit:** `feat(diagnostics): add baseline six-ball scenario`

- Add explicit diagnostic launch arguments for scenario, seed, warm-up, measurement duration, and NDJSON output.
- Run the existing six-Ball content through a deterministic diagnostic session and terminate cleanly after the requested window.
- Keep ordinary interactive app lifecycle unchanged when no scenario argument exists.
- Add an integration test that runs the scenario twice and compares structural counts, ticks, and sample kinds rather than noisy durations.

This commit proves the app can produce a deterministic stream before external capture tooling is introduced.

### Commit 11: Add the Capture Tool Skeleton

**Suggested commit:** `tooling: add diagnostics capture command`

- Add `Tools/diagnostics capture` with resolved input/output paths and an explicit built-app argument.
- Create the artifact directory, launch the scenario, redirect standard output, and validate the manifest and NDJSON stream.
- Record command/tool failure as a structured capture failure rather than leaving a plausible partial bundle.
- Test argument parsing, path validation, existing-output refusal, child-process failure, and a fixture-backed successful capture.

Building the app remains an outer workflow concern in this commit. Codex can build with Xcode's project-aware tools and pass the resolved app path; CI can supply its own previously built product.

### Commit 12: Capture Unified Logs

**Suggested commit:** `tooling: archive diagnostics logs`

- Extend the capture command to preserve the exact `.logarchive` window and filtered Engine2 NDJSON.
- Filter by the stable subsystem and capture session, include requested info/debug/signpost records, and report log loss or redaction.
- Add parser fixtures for normal records, redacted values, signposts, and loss entries.
- Keep unified-log absence distinct from proof that a runtime fact did not occur.

This is independent from Instruments and can be reviewed using small textual fixtures.

### Commit 13: Capture and Export Instruments Traces

**Suggested commit:** `tooling: export diagnostics traces`

- Add the checked-in os-signpost/Time Profiler capture configuration.
- Extend the capture command to preserve the native trace, export its ToC, and export only known signpost table schemas.
- Fail explicitly on an unrecognized Xcode/table schema and retain the native trace for manual inspection.
- Test ToC/schema selection with small exported XML fixtures; keep native traces out of source control.

Metal-specific templates are not included yet because no Render signposts exist at this point.

### Commit 14: Generate Summaries

**Suggested commit:** `tooling: summarize diagnostics captures`

- Add the `summarize` command and compute sample count, p50, p95, p99, maximum, structural inventory, and normalized cost only when its work count exists.
- Produce `summary.json` first and derive `summary.md` entirely from it.
- Add exact statistical fixtures, including empty, single-sample, warm-up exclusion, and incompatible-unit cases.

This commit reports measurements but does not decide whether a delta is acceptable.

### Commit 15: Compare Compatible Captures

**Suggested commit:** `tooling: compare diagnostics captures`

- Add manifest compatibility checks before calculating deltas.
- Compare structural counts and distributions, and distinguish regression, incompatibility, missing evidence, and correctness failure with separate result codes.
- Add fixtures for identical, improved, regressed, incompatible-hardware, incompatible-scenario, and missing-artifact comparisons.
- Do not add approved thresholds or CI enforcement yet.

At this point the complete repeatable Codex loop exists for Simulation and Input.

### Commit 16: Measure Render Projection

**Suggested commit:** `feat(render): instrument frame projection`

- Add `RenderProjection` around `RenderFrame.project(from:)` at the Render-owned call site.
- Report source tick plus published, accepted, and rejected presentation counts.
- Derive freshness later by correlating source tick with Simulation samples; do not give Render a direct Simulation Runtime dependency.
- Extend `RenderFrameTests` with valid, invalid-camera, singular-transform, and nonfinite-product sample expectations.

This pure projection slice is independently testable and does not touch Metal frame submission.

### Commit 17: Instrument Render CPU Work

**Suggested commit:** `feat(render): instrument frame preparation and encoding`

- Wire the existing diagnostics sink through `MetalSceneView` to `MetalRenderer` at App composition.
- Add `FrameSlotWait`, `FrameEncode`, and outer `RenderFrameCPU` intervals.
- Report frame sequence, source tick, whether the source tick changed, submitted instance count, render pass count, draw count, submesh count, missing drawable, and truncation.
- Reuse counts already produced by the draw path; do not add diagnostic-only mesh traversal.
- Extend `MetalRendererTests` and existing offscreen tests with recording-sink expectations.

This commit stops at queue commit. GPU feedback and asset construction remain separate ownership paths.

### Commit 18: Instrument Render Resource Construction

**Suggested commit:** `feat(render): instrument resource construction`

- Add `AssetLoad` and `PipelineCompile` intervals to `MetalResourceStore` construction paths.
- Publish model, mesh, submesh, pipeline, argument-table, material, and frame-resource inventory after successful construction.
- Log preserved typed errors without changing the store's failure behavior.
- Extend `MetalResourceStoreTests` and catalog tests with success, cache-hit, and construction-failure expectations.

Keeping construction separate prevents one frame-timing change from obscuring cache or eager-compilation review.

### Commit 19: Correlate GPU Completion

**Suggested commit:** `feat(render): correlate gpu submission feedback`

- Add a submission identity and `GPUFrame` interval from immediately before commit through Metal feedback.
- Correlate submission, render frame, source tick, frame slot, and terminal feedback result.
- Preserve existing frame-release and error-state ordering exactly.
- Extend `MetalInFlightSubmission` and offscreen submission tests for success, failure, and delayed feedback.

Add the Metal-oriented trace template to the capture tool only after this commit, either here when it is a small configuration addition or as a dedicated follow-up if schema fixtures are substantial.

### Commit 20: Add the Compact Diagnostics HUD

**Suggested commit:** `feat(debug-ui): add diagnostics hud`

- Extend `AppDebugOptions` and the Debug menu with one HUD toggle.
- Render only immutable `DiagnosticsSnapshot` aggregates at a bounded 5–10 Hz refresh cadence.
- Show Simulation state/backlog, Render freshness/in-flight pressure, frame distributions, work counts, and latest error state.
- Add stable accessibility identifiers, a fixture-driven preview, and focused state/presentation tests.

No history charts, recording controls, or export actions belong in this commit.

### Commit 21: Add the Expanded Dashboard

**Suggested commit:** `feat(debug-ui): add diagnostics dashboard`

- Add the bounded cadence lanes, system-duration chart, backlog/freshness graphs, presentation funnel, Render phase chart, and resource/error tables.
- Drive every view from a paused fixture or immutable `DiagnosticsSnapshot`.
- Provide a textual table or accessible summary for each chart.
- Verify representative empty, healthy, backlog, and render-error fixtures with previews and focused UI tests.

The dashboard is read-only in this commit, which keeps visualization defects separate from recorder control.

### Commit 22: Add Recording Controls and Interactive Export

**Suggested commit:** `feat(debug-ui): control and export diagnostics sessions`

- Add pause, scrub, reset, and capture-session controls.
- Add interactive export through an App-owned user-selected destination; do not broaden sandbox filesystem access.
- Add screenshot capture only as an outer tooling/UI-test action, not as Render Runtime responsibility.
- Test state transitions, cancellation, export errors, and schema-valid exported fixtures.

This completes the local debug experience without changing runtime authority.

### Commit 23: Add Release Performance Tests

**Suggested commit:** `test(performance): add diagnostics performance plan`

- Add a Release-configured XCTest performance plan with debugger, coverage, and sanitizers disabled.
- Add measurement cases for fixed steps, invariant systems, presentation capture, Render projection, and selected app-level signposts.
- Record CPU, memory, or signpost metrics only where each answers a named risk.
- Land the tests without accepting numerical baselines in the same commit.

Separating the harness from its first baselines makes test correctness review independent from performance-policy review.

### Commit 24: Establish Reviewed Budgets

**Suggested commit:** `perf: establish diagnostics baselines and budgets`

- Collect repeated compatible runs on the named machine class.
- Add small reviewed baseline summaries and budget metadata with scenario, rationale, owner, and review date.
- Extend `compare` to enforce only those approved budgets.
- Demonstrate the result with one passing and one intentionally regressed fixture.

Do not commit native traces or large capture directories.

## Conditional Follow-Up Commits

The following work should not be presented as an unconditional rollout step because each needs evidence or a product decision first:

- **CI enforcement:** add a dedicated commit only after deterministic CPU scenarios have remained stable across repeated unattended runs. Keep GPU/display budgets out of heterogeneous CI.
- **MetricKit report archival:** add one commit for the long-lived App-owned manager and versioned Codable report envelope, with simulated-payload tests.
- **MetricKit state attribution:** add a later commit for a small reviewed set of state-reporting domains after cardinality and privacy review.
- **Custom Instrument:** add a dedicated Instruments package only when at least two real investigations show that the ordinary signpost tracks and generated summary repeat the same manual analysis.

## Commit Boundary Rules

- Every commit builds and includes its relevant tests, fixtures, and DocC updates.
- Keep one production type per file and mirror new source paths under `Engine2Tests` where practical.
- Do not mix behavioral policy changes, such as a fixed-step overload clamp, into an instrumentation commit.
- Add or bump an artifact schema version in the same commit that changes encoded fields, fixtures, encoder, decoder, and compatibility rules.
- Keep performance-harness changes separate from accepting baselines or budgets.
- Keep debug visualization changes separate from runtime measurement sites.
- Never commit generated `.trace`, `.logarchive`, `.xcresult`, screenshot, or capture directories as implementation evidence.
- If a proposed slice cannot be described with one primary concern and one focused verification set, split it before implementation.

## Practices to Avoid

- Do not add a global mutable diagnostics singleton or service locator.
- Do not let the dashboard read live `World`, renderer caches, or GPU objects.
- Do not log or signpost per entity in hot loops.
- Do not use wall-clock timestamps as simulation identity.
- Do not dynamically create categories or signpost names from entity, asset-instance, or system-instance data.
- Do not publish private content merely to make local filters convenient.
- Do not treat a missing log entry as proof that an event did not occur.
- Do not compare Debug and Release, different scenarios, or incompatible hardware as if they were equivalent.
- Do not optimize from an average without sample count, distribution, work volume, and environment.
- Do not add an interval unless someone can state which decision it will support.

## Apple Guidance

This proposal follows Apple's current guidance:

- [Recording performance data](https://developer.apple.com/documentation/os/recording-performance-data) describes `OSSignposter`, unique signpost IDs, interval state, point events, and Instruments signpost tracks.
- [Generating log messages from your code](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code) defines subsystem/category organization, level persistence, formatting, and privacy behavior.
- [OSLogStore](https://developer.apple.com/documentation/oslog/oslogstore) provides programmatic access to filtered unified-log entries and log archives.
- [Writing and running performance tests](https://developer.apple.com/documentation/xcode/writing-and-running-performance-tests) recommends repeatable workloads, Release performance configuration, disabled debugger/sanitizers/coverage, and baseline comparison.
- [Improving your app's performance](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance) recommends a continuous measure-change-compare cycle, before/after Instruments profiles, and regression tests.
- [Analyzing the performance of your Metal app](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app) distinguishes display pacing, shader utilization, CPU utilization, scheduling, and CPU-GPU overlap.
- [Monitoring app performance with MetricKit](https://developer.apple.com/documentation/metrickit/monitoring-app-performance-with-metrickit) describes Codable reports, state attribution, diagnostic reports, and aggregated custom signpost metrics.

## Related Direction

- <doc:Runtime-Architecture>
- <doc:Runtime-Communication>
- <doc:Engine-Architecture>
- <doc:System-Scheduling>
- <doc:Rendering-Architecture>
