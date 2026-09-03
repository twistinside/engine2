# Engine2 Agent Guide

## Purpose and Sources of Truth

Engine2 is a Swift ECS experiment built around explicit ownership and typed boundaries. Preserve its core model:

- ECS component stores are the authoritative simulation state.
- Entity objects are ergonomic, typed facades over that state.
- Capability protocols provide the Game Content, UI, and tooling API.
- Systems that process component data operate directly on component stores.

This file contains durable repository-wide constraints. Source defines the current implementation, passing tests
establish enforced contracts, and DocC explains intended architecture. DocC may include partially implemented or
proposed direction. When relevant sources disagree, report the mismatch instead of silently treating a proposal as
current behavior.

Read only the architecture material relevant to the change:

- Runtime ownership, naming, lifecycle, and cadence:
  `Engine2/Engine2.docc/Articles/Runtime-Architecture.md`.
- Assembly topology and exact advancement:
  `Engine2/Engine2.docc/Articles/Runtime-Assemblies-and-Advancement.md`.
- Snapshots, events, requests, and delivery semantics:
  `Engine2/Engine2.docc/Articles/Runtime-Communication.md`.
- `Engine`, `World`, ECS systems, and entity facades:
  `Engine2/Engine2.docc/Articles/Engine-Architecture.md`.
- System stages and future scheduling:
  `Engine2/Engine2.docc/Articles/System-Scheduling.md`.
- Game Content, assets, and consumer extension boundaries:
  `Engine2/Engine2.docc/Articles/Game-Content-Architecture.md`.
- Render and GPU ownership:
  `Engine2/Engine2.docc/Articles/Rendering-Architecture.md` and
  `Engine2/Engine2.docc/Articles/Resource-Ownership-and-Presentation-Boundaries.md`.
- PBR, HDR, material validation, and Forward+ direction:
  `Engine2/Engine2.docc/Articles/PBR-Implementation-Plan.md`.

A documented limitation or proposal is not authorization to expand a focused task.

## Vocabulary and Runtime Ownership

- A **Runtime** is a long-lived top-level application object with its own state, lifecycle, cadence, and explicit
  boundaries. Concrete runtime types use a descriptive `Runtime` suffix.
- The **Simulation Runtime** owns authoritative gameplay state, including `Engine`, `World`, ECS resources, system
  execution, and completed Simulation publications. It does not own peer-runtime lifecycles.
- A **System** is scheduled logic inside the Simulation Runtime, not a top-level runtime. Concrete systems and
  components use descriptive `System` and `Component` suffixes. Protocols use their domain role without a marker prefix.
- A **Snapshot** is an immutable point-in-time boundary value. A snapshot type uses a descriptive `Snapshot` suffix.
- An **Event** is an immutable fact published within one runtime's authority. Optional consumers may observe it, but the
  publisher must remain correct when no consumer exists.
- **Game Content** is consumer-defined code, descriptions, catalogs, and packaged assets used to construct and configure
  runtimes. It is not a runtime and has no independent lifecycle or cadence.
- An **Asset** is packaged source content such as a model, texture, sound, animation, or level. A **Resource** is
  long-lived mutable non-entity state scoped to a Runtime or `World`. Keep those meanings distinct even though SwiftPM
  calls bundled files resources.

The App constructs and retains one Runtime Assembly from selected Game Content. The assembly constructs, wires, and
presents its Runtime topology through explicit dependencies. Runtimes must not discover peers through global mutable
state, service locators, or process-global resource registries.

There is no universal frame cadence. Platform input, fixed Simulation ticks, rendering, and future runtime work may
advance independently. Prefer snapshots and events for communication between peer runtimes. Use request/result
boundaries for deliberate directed dependencies, normally coordinated by the assembly or a focused assembly-owned
collaborator.

Latest-value snapshots may skip superseded values; they are not ordered streams or durable history. Introduce an
explicit owner, retention policy, and journal when a consumer requires history.

Do not rename or wrap a type solely to match the vocabulary. Introduce a Runtime boundary only when it creates concrete
ownership, lifecycle, cadence, isolation, or testing value. Do not introduce a routing or agent-control framework
without a concrete consumer and explicit identity, delivery, ownership, and lifecycle semantics.

## Simulation and ECS

`World` and its component stores are the simulation source of truth. Entity subclasses are live typed facades, not a
second authoritative state model. Keep `Entity` as the common base class for live game objects and prefer capability
protocols over deeper inheritance.

Systems that operate on component data must iterate or join stores directly rather than entity facades. Use
`ComponentStore.update(for:_:)` for an existing row. Use `insert` for registration, adding a missing row, or an
intentional full reset or reseed. Do not rebuild and reinsert rows for ordinary per-tick field changes.

`World.add(_:from:)` validates agreement between an entity's advertised capabilities and its complete
`Entity.InitialState`, then creates the authoritative component rows. Concrete entity initializers assemble typed
initial state and register through this boundary. Keep every construction-time component write inside
`World.add(_:from:)`.

Preserve complete `EntityID` identity, including `generation`. Sparse lookup may start from the index, but validation,
equality, enumeration, and tie-breaking must not regress to index-only semantics. Do not introduce index reuse until
component removal, dense compaction, and direct iteration are safe for stale generations.

Motion systems accumulate contributions before integration. Do not let unrelated systems or entity facades overwrite
integrated velocity unless the operation is an explicit constraint, collision response, or dynamic-motion override.
Rail-driven and dynamically integrated motion are mutually exclusive policies; transition between them explicitly.
Apply the same contribution model to angular motion.

`SimulationRuntime.fixedTimeStep` defines the production duration of one tick. Assembly policy may decide when to
request work, but it must not redefine the tick or execute a partial schedule. `Engine` executes one complete ordered
schedule for every accepted step. Game Content contributes systems only through `SimulationBehavior` and the fixed
`SimulationSystemSchedule` stages; it must not bypass the Engine-owned execution order.

## Input and UI Boundaries

Input Runtime owns platform device state and context-free physical-to-semantic mapping. Its configuration may define
bindings and sensitivity, but it must not name entities, inspect `World`, or make gameplay decisions. Simulation imports
immutable input publications at fixed-step boundaries and interprets semantic intent using authoritative ECS state.
Keep semantic mapping, gameplay policy, and rendering logic out of platform views. `InputEvent` is platform ingress, not
a published ordered event journal.

UI that inspects live gameplay state outside presentation snapshots must use a narrow read-only Simulation-owned
source. Selected-entity inspection resolves a registered live facade for a complete `EntityID`. Route actions that
mutate Simulation state through focused callbacks and typed requests. Do not expose `World`, mutate live facades from
SwiftUI, or add gameplay-only state to a render presentation snapshot merely to support an inspector.

## Game Content

Game Content owns exhaustive, strongly typed, backend-neutral asset and content identities used by its entities,
including `MeshID` and `MaterialID`. Runtimes may carry and resolve those identities, but they do not own the content
vocabulary. `World` owns `EntityID` allocation.

The Runtime performing work owns the interface it consumes and privately resolves content into operational resources.
Never store raw Metal buffers, decoded backend objects, caches, or other Runtime allocations in ECS or Game Content. Do
not make every internal type public; expose the smallest coherent API required by an external content consumer.

Keep component storage strongly typed and per component type. Do not solve consumer-defined component support with a
closed component enum or a process-global registry.

## Presentation and Render

Render consumes completed `SimulationPresentationSnapshot` values and must not read live `World` state. The real-time
screen uses the camera contained in that completed snapshot. Any editor, replay, spectator, or multi-window viewpoint
must belong to an explicit assembly or output mode; ordinary pause must not create an implicit camera bypass.

Render owns backend state. Retain every object required by submitted GPU work until real queue feedback proves that work
completed; cancellation after commit must not abandon in-flight resources.

## Swift, Files, and Documentation

Follow `.agents/swift/preferences.md` for Swift work. Consult the relevant files under `.agents/swift/examples/` when
designing or substantially rewriting Swift code.

Keep one repository-owned type per file and name the file after that type.

Prefer domain types when raw `Int` or `String` values would admit invalid states or meaningless operations. Use an enum
for a known finite vocabulary. If an external or genuinely open-ended API requires strings, document that reason.

Do not add Xcode-style headers that repeat a filename or project name, record authorship or creation dates, or add
boilerplate copyright text. Remove such a header only when modifying that file or when cleanup is explicitly requested.

Follow `.agents/writing/style-guide.md` for all repository prose, including code comments and comments in tests.

Do not perform unrelated prose or code cleanup during a focused change. When explicitly asked to record architecture
ideas or future direction, update the relevant DocC article, distinguish implemented behavior from proposed work, and
link a new conceptual article from the DocC landing page when it represents durable design.

## Tests and Tooling

Mirror direct production-type and method tests under `Engine2UnitTests/` using the corresponding source-tree structure
where practical.

Place Render tests that cross production boundaries under `Engine2RenderTests/`. This includes real shader execution,
command submission, GPU lifetime, renderer assembly, and packaged-model decoding. Keep test-only Render infrastructure
private to that target.

Prefer project-aware Xcode tooling for builds, tests, file reads, diagnostics, and project validation. Use
compiler-backed Swift semantic tooling when available for definitions, references, conformances, call relationships,
and diagnostics. Prefer Apple documentation tooling for framework and API questions before general web search.
