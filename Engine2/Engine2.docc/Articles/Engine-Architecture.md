# Engine Architecture

Engine2 is organized around a small set of responsibilities that are meant to stay separate as the engine grows.

## Current Runtime Roles

### Engine

``Engine`` owns time accumulation and simulation orchestration.

At the moment, it:

- accumulates incoming frame time
- advances simulation in fixed-size steps
- runs systems in a stable call order

This keeps timing and scheduling logic out of ``World``.

### Game and World Builders

``Game`` sits above ``Engine`` and owns session bootstrap policy.

It decides which ``WorldBuilder`` to use for a new game, generated scenario, or
loaded save, and it can rebuild or replace the active world inside the engine
when the session changes.

`Game` also owns the higher-level loop that polls wall time and advances the
engine. The app should keep one top-level `Game` reference and start or stop it
with host lifecycle events.

``WorldBuilder`` types are not simulation ``System`` implementations. They are
one-shot construction helpers that produce a fully bootstrapped ``World`` before
or between simulation runs.

### World

``World`` is the authoritative container for simulation state.

It owns the component stores, simulation-scoped resources, and entity identity lifecycle. The world is not the scheduler and should not decide when simulation advances.

### Systems

``System`` implementations contain simulation logic.

They receive mutable access to the world for a single step and perform real gameplay work by reading and writing component stores directly. Systems are intended to be data-oriented and should avoid routing hot-path logic through entity facade objects.

### Presentation and Rendering

Rendering is an engine subsystem, but it is not itself a simulation ``System``.

The world may contain abstract presentation state such as mesh handles, material handles, camera data, visibility flags, or render style. Backend-specific render state should remain inside the render layer.

The intended boundary is:

1. systems update `World`
2. a presentation export or extraction step builds render-facing frame data
3. the renderer consumes that exported frame data

This keeps `World` authoritative without making it the owner of Metal or other backend objects.

### Entity Facades

``Entity`` subclasses such as ``Ball`` remain useful as typed, ergonomic objects at the game boundary, UI boundary, and inspection layer.

They are not the runtime source of truth. Runtime truth lives in the world's component stores.

## Fixed-Step Simulation

The current simulation model is a fixed-step loop:

1. Real frame time is added to the engine's accumulator.
2. The engine executes as many fixed simulation steps as fit inside that accumulated time.
3. Each step runs the registered systems against the current world state.

This model keeps systems working in terms of simulation time rather than render-frame timing.

At the application boundary, host code decides when the session should run or
pause. ``Game`` owns the polling loop that samples real time and feeds that
delta into ``Engine.update(deltaTime:)``.

That outer loop stays above `Engine` so the engine remains reusable in tests,
tools, and future host applications with different lifecycle needs.

Drawing is expected to run on its own presentation cadence. A draw can occur with no new simulation step, and several simulation steps can happen before one draw.

## Current Limits

The current engine is still early. Several important behaviors are intentionally simple or incomplete:

- entity ID reservation is monotonic only; destruction, generation incrementing,
  and index reuse have not been added yet
- world/entity translation at spawn time covers the current capability protocols,
  but lifecycle and reseeding semantics are still intentionally small
- systems currently run in a single ordered list
- overload protection for the fixed-step loop has not been added yet
- the extraction boundary between simulation and rendering is still only documented direction

## Topics

### Core Symbols

- ``Engine``
- ``World``
- ``System``
- ``Entity``
- ``ComponentStore``
