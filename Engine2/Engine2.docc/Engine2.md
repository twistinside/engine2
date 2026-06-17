# ``Engine2``
Engine2 is a small ECS-first engine experiment with typed entity facades, per-type component stores, and a fixed-step simulation loop.
## Overview
The current codebase is intentionally small, but the core direction is already established:
- ``World`` owns authoritative simulation state.
- ``Engine`` owns fixed-step orchestration and system execution.
- ``PSystem`` implementations operate on component stores, not object facades, in hot paths.
- ``Entity`` subclasses and capability protocols remain the ergonomic game-facing layer.
- Rendering is an engine subsystem with a current ``RenderFrame`` extraction boundary rather than a second gameplay state model.
This documentation catalog serves two purposes:
- document the behavior that already exists in the codebase
- capture architectural direction that is intentionally not implemented yet
At the moment, the codebase already includes:
- a two-list system runner in ``Engine`` for always-running input/tool systems and simulation-gated systems
- a main-actor ``GameLoop`` that polls wall time and advances the fixed-step engine
- a current render extraction path via ``RenderFrame.extract(from:)`` and ``MetalSceneView``
## Topics
### Architecture
- <doc:Engine-Architecture>
- <doc:Resource-Ownership-and-Presentation-Boundaries>
- <doc:Rendering-Architecture>
### Scheduling
- <doc:System-Scheduling>
