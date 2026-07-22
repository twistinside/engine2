# ``Engine2``
Engine2 is a small ECS-first engine experiment with typed entity facades, per-type component stores, and an exact fixed-step simulation core.
## Overview
The current codebase is intentionally small, but the core direction is already established:
- The App owns independent top-level runtimes connected through explicit typed snapshot and event publications.
- ``InputRuntime`` accepts platform input through `PInputEventSink` and publishes a revisioned latest `InputSnapshot` through `PInputSnapshotSource`.
- The Simulation Runtime is authoritative for gameplay state and contains the engine, world, and ECS systems.
- Game Content supplies consumer-defined entities, world construction, presentation descriptions, and assets without becoming a runtime.
- ``World`` owns authoritative simulation state.
- ``Engine`` owns exact fixed-step execution and ordered system orchestration; its elapsed-time adapter remains only as a legacy migration path.
- ``PSystem`` implementations operate on component stores, not object facades, in hot paths.
- ``Entity`` subclasses and capability protocols remain the ergonomic game-facing layer.
- ``SimulationRuntime`` publishes its latest completed ``SimulationPresentationSnapshot`` and Render derives its private ``RenderFrame`` projection without reading live ``World`` state.
This documentation catalog serves two purposes:
- document the behavior that already exists in the codebase
- capture architectural direction that is intentionally not implemented yet
At the moment, the codebase already includes:
- an App-owned Input Runtime whose immutable latest snapshot is captured by ``RealtimeAdvanceDriver`` and assigned to an exact Simulation request
- a two-list system runner in ``Engine`` for always-running input/tool systems and simulation-gated systems
- an App-owned real-time driver that translates wall time into cursor-qualified exact requests, plus a clock-free ``ManualConfiguration``
- an app-facing ``SimulationRuntime`` that owns session bootstrap, serialized exact advancement, world construction policy, and completed publication
- a presentation-snapshot publication and render projection path via ``SimulationPresentationSnapshot``, ``RenderFrame.project(from:)``, and ``MetalSceneView``

``SimulationLoop`` and ``Engine.update(deltaTime:inputSnapshot:)`` remain in the source tree only as unused legacy migration paths; new App composition advances through the Runtime-level exact capability.
## Topics
### Architecture
- <doc:Runtime-Architecture>
- <doc:Runtime-Configurations-and-Advancement>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
- <doc:Engine-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
- <doc:Rendering-Architecture>
- <doc:PBR-Implementation-Plan>
### Scheduling
- <doc:System-Scheduling>
