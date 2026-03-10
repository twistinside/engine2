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

### World

``World`` is the authoritative container for simulation state.

It owns the component stores and entity identity lifecycle. The world is not the scheduler and should not decide when simulation advances.

### Systems

``System`` implementations contain simulation logic.

They receive mutable access to the world for a single step and perform real gameplay work by reading and writing component stores directly. Systems are intended to be data-oriented and should avoid routing hot-path logic through entity facade objects.

### Entity Facades

``Entity`` subclasses such as ``Missile`` remain useful as typed, ergonomic objects at the game boundary, UI boundary, and inspection layer.

They are not the runtime source of truth. Runtime truth lives in the world's component stores.

## Fixed-Step Simulation

The current simulation model is a fixed-step loop:

1. Real frame time is added to the engine's accumulator.
2. The engine executes as many fixed simulation steps as fit inside that accumulated time.
3. Each step runs the registered systems against the current world state.

This model keeps systems working in terms of simulation time rather than render-frame timing.

## Current Limits

The current engine is still early. Several important behaviors are intentionally simple or incomplete:

- entity ID reservation is still placeholder logic
- world/entity translation at spawn time is still skeletal
- systems currently run in a single ordered list
- overload protection for the fixed-step loop has not been added yet

## Topics

### Core Symbols

- ``Engine``
- ``World``
- ``System``
- ``Entity``
- ``ComponentStore``
