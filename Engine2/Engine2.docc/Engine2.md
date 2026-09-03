# ``Engine2``

Engine2 is a compact ECS-first engine experiment with typed entity facades, per-type component stores, and exact fixed-step simulation.

## Overview

The current release has one real-time interactive topology:

- ``Engine2App`` selects Game Content and constructs a ``RealtimeAssembly`` through ``RuntimeAssembly/init(using:)``. The assembly owns its Runtime graph, lifecycle policy, and root SwiftUI presentation.
- ``InputRuntime`` maps platform input into context-free semantic intent and publishes immutable ``InputSnapshot`` values.
- ``SimulationRuntime`` owns the authoritative ``World``, ``Engine``, ECS resources, and systems. ``Engine`` executes one complete ordered schedule at ``SimulationRuntime/fixedTimeStep``.
- ``SimulationBehavior`` contributes Game Content systems only through the fixed stages in ``SimulationSystemSchedule``. The Engine retains its foundational input, camera, integration, and cleanup work.
- ``SimulationRuntime`` publishes completed ``SimulationPresentationSnapshot`` values. The screen renderer consumes those values without reading live ECS state or maintaining a second camera.
- ``MetalSceneView`` connects the platform view, Input Runtime, and ``MetalRenderer``. ``MetalFrameEncoder`` owns reusable view-independent frame encoding.

Component stores remain the source of truth for Simulation. ``Entity`` subclasses and capability protocols provide a typed facade for Game Content, UI, and tooling. Game Content supplies authored entities, construction policy, behavior, backend-neutral presentation descriptions, and assets; each Runtime owns the resources and lifecycle needed to consume them.

The articles in this catalog distinguish implemented behavior from proposed architecture. Offscreen output, replay, agent control, generalized routing, multi-window bindings, and additional top-level Runtimes remain future work.

## Topics

### Runtime and Application

- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Runtime-Communication>

### Simulation and Game Content

- <doc:Engine-Architecture>
- <doc:System-Scheduling>
- <doc:Game-Content-Architecture>

### Rendering

- <doc:Rendering-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
- <doc:PBR-Implementation-Plan>
