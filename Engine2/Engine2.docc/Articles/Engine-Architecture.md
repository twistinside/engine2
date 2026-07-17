# Engine Architecture
Engine2 is organized around a small set of responsibilities that are meant to stay separate as the engine grows.
The engine, world, and ECS systems described here are the internal architecture of the authoritative ``SimulationRuntime``. See <doc:Runtime-Architecture> for the top-level application model and runtime-boundary vocabulary.
## Current Simulation Roles
### Engine
``Engine`` owns time accumulation and simulation orchestration.
At the moment, it:
- accumulates incoming frame time
- advances simulation in fixed-size steps
- runs always-running systems in a stable call order
- runs simulation systems in a second stable call order only when simulation is enabled
This keeps timing and scheduling logic out of ``World``.
### Simulation Runtime and World Builders
``SimulationRuntime`` sits above ``Engine`` and owns session bootstrap and lifecycle policy.
It accepts a ``PWorldBuilder`` for a new simulation, generated scenario, or loaded save, and can rebuild or replace the active world when the session changes. It also owns ``SimulationLoop``, which polls wall time and advances the engine in response to host lifecycle events.
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
The current simulation model is a fixed-step loop:
1. Real frame time is added to the engine's accumulator.
2. The engine executes as many fixed simulation ticks as fit inside that accumulated time.
3. Each tick runs the registered systems against the current world state.
This model keeps systems working in terms of simulation time rather than render-frame timing.
At the application boundary, host code decides when the session should run or pause. ``SimulationRuntime`` owns ``SimulationLoop``, which samples real time and feeds that delta into ``Engine.update(deltaTime:)``. That outer loop stays above `Engine` so the engine remains reusable in tests, tools, and future host applications with different lifecycle needs. Drawing is expected to run on its own presentation cadence. A draw can occur with no new simulation tick, and several simulation ticks can happen before one draw.
## Current Limits
The current engine is still early. Several important behaviors are intentionally simple or incomplete:
- entity ID reservation is monotonic only; destruction, generation incrementing, and index reuse have not been added yet
- world/entity translation at spawn time covers the current capability protocols, but lifecycle and reseeding semantics are still intentionally small
- systems currently run in two ordered lists: always-running input/tool systems and simulation-gated systems
- overload protection for the fixed-step loop has not been added yet
- live simulation publication currently exposes only a latest completed ``SimulationPresentationSnapshot``; other semantic publications, retained history, replay storage, and offscreen rendering remain future work
## Topics
### Core Symbols
- ``Engine``
- ``World``
- ``PSystem``
- ``Entity``
- ``ComponentStore``
### Related Architecture
- <doc:Runtime-Architecture>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
