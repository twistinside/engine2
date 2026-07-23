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
- ``SimulationRuntime`` publishes its latest completed ``SimulationPresentationSnapshot``. The snapshot camera is a publisher-authored default, not a requirement that every output use one Simulation-mutated view.
- The App-owned ``ScreenViewpointController`` can change one screen's presentation while Simulation is paused. Render combines its immutable ``RenderViewpoint`` with the exact Simulation snapshot and records both Simulation-cursor and optional viewpoint attribution in ``RenderFrame``.
- ``MetalFrameEncoder`` prepares and encodes the reusable Metal frame against caller-owned textures, frame resources, and a command buffer without depending on MetalKit view or drawable ownership.
- ``POffscreenRenderTarget`` accepts an exact immutable snapshot, explicit viewpoint, and render settings asynchronously. ``MetalOffscreenRenderRuntime`` implements that capability with dedicated one-slot Metal resources and returns detached pixels with exact request, scene, viewpoint, and settings provenance.
- ``JPEGArtifactEncoder`` transforms a completed raw offscreen result into a detached JPEG artifact on the CPU. The stateless encoder preserves exact source provenance, chooses no execution context, and can be retried without advancing Simulation or rerendering.
- ``OfflineCaptureConfiguration`` composes one closed serial advance-render-encode topology. Its assembly exposes only the initial cursor and ``POfflineCaptureTarget``, keeping ``OfflineCaptureCoordinator`` as the sole effective advance authority. The coordinator validates completed image extent and cancellation identity, then immediately awaits non-cancellation-inheriting JPEG work outside its actor while preserving busy backpressure.
This documentation catalog serves two purposes:
- document the behavior that already exists in the codebase
- capture architectural direction that is intentionally not implemented yet
At the moment, the codebase already includes:
- an App-owned Input Runtime whose immutable latest snapshot is captured by ``RealtimeAdvanceDriver`` and assigned to an exact Simulation request
- a two-list system runner in ``Engine`` whose exact-step path executes the complete schedule; the default schedule no longer installs the legacy `SInputMapping` or `SCameraInput` camera path
- an App-owned real-time driver that translates wall time into cursor-qualified exact requests, plus a clock-free ``ManualConfiguration``
- an app-facing ``SimulationRuntime`` that owns session bootstrap, serialized exact advancement, world construction policy, and completed publication
- a current real-time assembly that explicitly fans screen host events to both ``InputRuntime`` and ``ScreenViewpointController`` while leaving Simulation advancement under the separate driver
- a presentation-snapshot, explicit-viewpoint, and render-projection path via ``SimulationPresentationSnapshot``, ``RenderViewpoint``, ``RenderFrame.project(from:viewpoint:)``, and ``MetalSceneView``
- a view-independent production ``MetalFrameEncoder`` shared by the thin MetalKit screen adapter, the exact offscreen Runtime, and their render integration coverage
- a production exact offscreen request/outcome boundary with strict presentation/model/geometry preflight, configurable safety limits, single-flight backpressure, queue-feedback lifetime, cancellation semantics, and tightly packed top-left BGRA8-sRGB readback
- a stateless JPEG artifact layer with validated quality, detached encoded data, and exact request/cursor/viewpoint/render/encoding provenance
- a concrete serial offline capture configuration whose typed outcomes preserve committed Simulation progress and, after rendering, the raw result needed for retryable artifact derivation

``SimulationLoop``, ``Engine.update(deltaTime:inputSnapshot:)``, `SInputMapping`, and `SCameraInput` remain in the source tree only as legacy migration paths or focused-test seams; new App composition advances through the Runtime-level exact capability and owns screen viewpoint control outside Simulation. Exact raw offscreen rendering, CPU-side JPEG derivation, and one serial offline capture assembly are implemented. That assembly has no Input Runtime, automatic cadence, screen, optional-runtime bag, persistence, or implicit retry/rollback. A dedicated render actor or worker, pooled targets, high-quality accumulation and HDR-master policy, PNG encoding, artifact persistence/sinks, typed multi-source routing, multi-window bindings, observer anchors, and MCP transport/idempotency remain proposed.
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
