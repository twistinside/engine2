# Engine Architecture
Engine2 is organized around a small set of responsibilities that are meant to stay separate as the engine grows.
The engine, world, and ECS systems described here are the internal architecture of the authoritative ``SimulationRuntime``. See <doc:Runtime-Architecture> for the top-level application model and runtime-boundary vocabulary, and <doc:Runtime-Assemblies-and-Advancement> for the implemented exact-advance boundary and the broader proposed assembly model.
## Current Simulation Roles
### Engine
``Engine`` owns exact fixed-step execution and ordered system orchestration.
At the moment, its exact path:
- imports an immutable input assignment only when the first requested fixed step begins
- advances simulation in fixed-size steps
- runs one complete system schedule in stable call order

``Engine`` has no elapsed-time accumulator or simulation-gated partial
schedule. Wall-time accumulation and pause policy belong to
``RealtimeAdvanceDriver``; a completed tick always means the complete schedule
ran once.

Production construction receives one validated ``SimulationConfiguration`` and
one ``PSimulationBehavior``. The Engine builds its invariant camera,
integration, history, and cleanup foundation from the Simulation policy, then
inserts the behavior's ``SimulationSystemSchedule`` systems only at the named
`inputConsumption`, `worldPreparation`, `forceContribution`, `postMovement`,
and `prePresentation` stages. Physical bindings and pointer/scroll sensitivity
belong to the Input Runtime's `InputMappingConfiguration`, not Simulation. The
complete injected-systems initializer remains available for focused integration
tests, but it requires the `World`, fixed step, and entire system list explicitly.
This keeps timing and scheduling logic out of ``World``.
### Simulation Runtime and World Builders
``SimulationRuntime`` sits above ``Engine`` and owns session bootstrap, serialized exact advancement, world-construction policy, explicit Simulation behavior configuration, and publication of committed results.
It accepts a ``PWorldBuilder``, ``SimulationConfiguration``, and ``PSimulationBehavior`` for a new simulation, generated scenario, or loaded save, and can rebuild or replace the active world when the session changes. Builder replacement without reconstruction and builder replacement with immediate reconstruction are separately named operations; input baselines are explicit at construction and rebuild call sites. Its narrow ``PSimulationAdvanceTarget`` capability validates an optional expected ``SimulationCursor``, applies the request's immutable input assignment, executes the requested number of complete steps, and returns a correlated result.

Cadence is deliberately outside that boundary. The assembly-owned ``RealtimeAdvanceDriver`` polls wall time and samples `PInputSnapshotSource`; a manual caller can advance with no clock or Input Runtime. Future offline, MCP, network, and replay coordinators can use the same exact capability. Simulation retains the fixed-step definition, complete system schedule, cursor identity, authoritative mutation, and publication of committed results.
``PWorldBuilder`` types are not simulation ``PSystem`` implementations. They are one-shot construction helpers that produce a fully bootstrapped ``World`` before or between simulation runs.
The Simulation Runtime owns the ``PWorldBuilder`` interface because it consumes that contract. Consumer-defined builders, entity types, components, and presentation descriptions belong to Game Content. The Runtime Assembly supplies that content while constructing the Simulation Runtime; the runtime does not discover content through global registries. See <doc:Game-Content-Architecture>.
### World
``World`` is the authoritative container for simulation state.
It owns the component stores, simulation-scoped resources, and entity identity lifecycle. The world is not the scheduler and should not decide when simulation advances.
### Systems
``PSystem`` implementations contain simulation logic.
They receive mutable access to the world for a single step and perform real gameplay work by reading and writing component stores directly. Systems are intended to be data-oriented and should avoid routing hot-path logic through entity facade objects.
``Engine`` owns the invariant schedule required for a valid simulation, including camera, position, orientation, input-history, and cleanup mechanics. Game Content behavior enters only through ``PSimulationBehavior`` and ``SimulationSystemSchedule``; it does not assemble, replace, or reorder the required foundation.

Authoritative translational positions, velocities, accelerations, impulses, and fixed-step seconds use `Double`.
Completed presentation snapshots deliberately narrow positions to `Float`; Render, camera, and GPU values remain single
precision.

### Semantic Input and Selection

``InputRuntime`` publishes context-free translation and interaction intent plus cumulative camera and selection values. At a fixed-step boundary, Simulation derives interval-local changes and interprets them using authoritative ECS state. Selection resolution updates selection components, and control routing applies held translation or interaction only when the selected entity advertises player control. Selecting a non-controllable entity or clearing selection removes commanded control; the Input Runtime never receives an entity identity.

### Mining Slice Dynamics

The mining slice composes two authoritative motion policies inside the same schedule. The star supplies gravity, and the skiff dynamically integrates gravity, thrust, fuel use, changing cargo mass, and collision response. Asteroids and the depot follow deterministic analytic circular rails whose systems prepare their position and velocity before force contribution and integration.

A rail is a complete motion policy, not a force contribution. Do not run a rail writer and dynamic integration against the same body. A future perturbation feature must define an explicit transition from rail state to dynamic position and velocity.

### Presentation and Rendering
Rendering belongs to the proposed Render Runtime and is not itself a simulation ``PSystem``.
The world may contain abstract presentation state such as mesh handles, material handles, camera data, visibility flags, or render style. Backend-specific render state should remain inside the render layer.
The intended boundary is:
1. systems update `World`
2. the Simulation Runtime publishes a completed `SimulationPresentationSnapshot`
3. the Render Runtime projects published state into private render-facing frame data
4. the renderer consumes that private frame data
This keeps `World` authoritative without making it the owner of Metal or other backend objects.

### Entity Facades
``Entity`` subclasses such as ``Ball`` remain useful as typed, ergonomic objects at the game boundary, UI boundary, and inspection layer.
They are not the simulation source of truth. Authoritative gameplay state lives in the world's component stores.

The selected-entity SwiftUI inspector receives one narrow Simulation-owned source that resolves the current full ``EntityID`` to a live facade. It conditionally renders the capability protocols that facade supports. It does not receive `World` and does not add fuel, cargo, orbit, mining, or other gameplay fields to ``SimulationPresentationSnapshot``.

## Fixed-Step Simulation
The current portable simulation primitive is an exact Runtime-level request:

1. A caller supplies an optional expected ``SimulationCursor``, a positive step count, and one immutable semantic input assignment.
2. ``SimulationRuntime`` validates the expected cursor inside its serialized mutation domain.
3. A rebase assignment establishes held intent without replaying older camera or selection totals, an ingest assignment is consumed only at the first requested tick boundary, and rebase-then-ingest atomically preserves input published after a captured transition baseline.
4. ``Engine`` executes the complete ordered schedule exactly as many times as requested.
5. ``SimulationRuntime`` publishes the final completed presentation snapshot and returns initial/final cursors with the completed step count.

This keeps systems working in simulation time without giving wall time, drawing, or a tool invocation authority over what one tick means. ``SimulationRuntime/fixedTimeStep`` is the single production 1/60-second definition; assembly policy cannot substitute another duration. In ``RealtimeAssembly``, ``RealtimeAdvanceDriver`` owns host polling, elapsed-time remainder, pause/rebase policy, latest input capture, and conversion into exact batches. ``ManualAssembly`` proves the same Simulation Runtime can progress without a wall clock or Input Runtime. Drawing remains independent: a draw can occur with no new tick, and several ticks can complete before one draw.

``Engine`` now exposes only exact complete-step execution. New assemblies must not fabricate elapsed wall time or bypass ``SimulationRuntime`` by calling `Engine.step(inputSnapshot:)` directly.
## Current Limits
The current engine is still early. Several important behaviors are intentionally simple or incomplete:
- entity ID reservation is monotonic only; destruction, generation incrementing, and index reuse have not been added yet
- world/entity translation at spawn time covers the current capability protocols, but lifecycle and reseeding semantics are still intentionally small
- systems run in one ordered schedule with controlled Game Content insertion stages; dependency-derived ordering and safe parallelism remain future work
- the real-time driver's catch-up cap and overflow treatment are static driver policy; production telemetry and adaptive overload handling remain future work
- broader advance-authority arbitration and cursor-mismatch recovery remain App or assembly policy beyond the driver's initial fail-closed behavior
- the latest completed general publication remains ``SimulationPresentationSnapshot``; the selected-entity source is a narrow in-process live view, while other semantic publications, retained publication history, and replay storage remain future work
## Topics
### Core Symbols
- ``Engine``
- ``SimulationConfiguration``
- ``PSimulationBehavior``
- ``SimulationSystemSchedule``
- ``World``
- ``PSystem``
- ``Entity``
- ``ComponentStore``
### Related Architecture
- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
