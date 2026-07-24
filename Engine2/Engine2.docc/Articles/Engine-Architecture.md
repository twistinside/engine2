# Engine Architecture
Engine2 is organized around a small set of responsibilities that are meant to stay separate as the engine grows.
The engine, world, and ECS systems described here are the internal architecture of the authoritative ``SimulationRuntime``. See <doc:Runtime-Architecture> for the top-level application model and runtime-boundary vocabulary, and <doc:Runtime-Configurations-and-Advancement> for the implemented exact-advance boundary and the broader proposed configuration model.
## Current Simulation Roles
### Engine
``Engine`` owns exact fixed-step execution and ordered system orchestration.
At the moment, its exact path:
- imports an immutable input assignment only when the first requested fixed step begins
- advances simulation in fixed-size steps
- runs one complete foundational system schedule in stable call order

``Engine`` has no elapsed-time accumulator or simulation-gated partial
schedule. Wall-time accumulation and pause policy belong to
``RealtimeAdvanceDriver``; a completed tick always means the complete schedule
ran once.
This keeps timing and scheduling logic out of ``World``.
### Simulation Runtime and World Builders
``SimulationRuntime`` sits above ``Engine`` and owns session bootstrap, serialized exact advancement, world-construction policy, and publication of committed results.
It accepts a ``PWorldBuilder`` for a new simulation, generated scenario, or loaded save, and can rebuild or replace the active world when the session changes. Its narrow ``PSimulationAdvanceTarget`` capability validates an optional expected ``SimulationCursor``, applies the request's immutable input assignment, executes the requested number of complete steps, and returns a correlated result.

Cadence is deliberately outside that boundary. The App-owned ``RealtimeAdvanceDriver`` polls wall time and samples `PInputSnapshotSource`; a manual caller can advance with no clock or Input Runtime. Future offline, MCP, network, and replay coordinators can use the same exact capability. Simulation retains the fixed-step definition, complete system schedule, cursor identity, authoritative mutation, and publication of committed results.
``PWorldBuilder`` types are not simulation ``PSystem`` implementations. They are one-shot construction helpers that produce a fully bootstrapped ``World`` before or between simulation runs.
The Simulation Runtime owns the ``PWorldBuilder`` interface because it consumes that contract. Consumer-defined builders, entity types, components, and presentation descriptions belong to Game Content. The App supplies that content while constructing the Simulation Runtime; the runtime does not discover content through global registries. See <doc:Game-Content-Architecture>.
### World
``World`` is the authoritative container for simulation state.
It owns the component stores, simulation-scoped resources, and entity identity lifecycle. The world is not the scheduler and should not decide when simulation advances.
### Systems
``PSystem`` implementations contain simulation logic.
They receive mutable access to the world for a single step and perform real gameplay work by reading and writing component stores directly. Systems are intended to be data-oriented and should avoid routing hot-path logic through entity facade objects.
``Engine`` owns the invariant schedule required for a valid simulation, including position and orientation mechanics. Future consumer-defined behavior may be admitted through controlled extension points, but Game Content does not assemble or replace the required schedule.
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

## Fixed-Step Simulation
The current portable simulation primitive is an exact Runtime-level request:

1. A caller supplies an optional expected ``SimulationCursor``, a positive step count, and one immutable input assignment.
2. ``SimulationRuntime`` validates the expected cursor inside its serialized mutation domain.
3. A rebase assignment establishes held input without replaying older transient totals, an ingest assignment is consumed only at the first requested tick boundary, and rebase-then-ingest atomically preserves input published after a captured transition baseline.
4. ``Engine`` executes the complete ordered schedule exactly as many times as requested.
5. ``SimulationRuntime`` publishes the final completed presentation snapshot and returns initial/final cursors with the completed step count.

This keeps systems working in simulation time without giving wall time, drawing, or a tool invocation authority over what one tick means. ``SimulationRuntime/fixedTimeStep`` is the single production 1/60-second definition; configurations cannot substitute another duration. In ``RealtimeConfiguration``, ``RealtimeAdvanceDriver`` owns host polling, elapsed-time remainder, pause/rebase policy, latest input capture, and conversion into exact batches. ``ManualConfiguration`` proves the same Simulation Runtime can progress without a wall clock or Input Runtime. Drawing remains independent: a draw can occur with no new tick, and several ticks can complete before one draw.

``Engine`` now exposes only exact complete-step execution. New configurations must not fabricate elapsed wall time or bypass ``SimulationRuntime`` by calling ``Engine.step(inputSnapshot:)`` directly.
## Current Limits
The current engine is still early. Several important behaviors are intentionally simple or incomplete:
- entity ID reservation is monotonic only; destruction, generation incrementing, and index reuse have not been added yet
- world/entity translation at spawn time covers the current capability protocols, but lifecycle and reseeding semantics are still intentionally small
- systems currently run in one foundational ordered schedule; dependency-derived stages and safe parallelism remain future work
- the real-time driver's catch-up cap and overflow treatment are static configuration policy; production telemetry and adaptive overload handling remain future work
- broader advance-authority arbitration and cursor-mismatch recovery remain App/configuration policy beyond the driver's initial fail-closed behavior
- live simulation publication currently exposes only a latest completed ``SimulationPresentationSnapshot``; other semantic publications, retained history, and replay storage remain future work
## Topics
### Core Symbols
- ``Engine``
- ``World``
- ``PSystem``
- ``Entity``
- ``ComponentStore``
### Related Architecture
- <doc:Runtime-Architecture>
- <doc:Runtime-Configurations-and-Advancement>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
