# ``Engine2``
Engine2 is a small ECS-first engine experiment with typed entity facades, per-type component stores, and an exact fixed-step simulation core.
## Overview
The current codebase is intentionally small, but the core direction is already established:
- The App owns independent top-level runtimes connected through explicit typed snapshot and event publications.
- ``InputRuntime`` accepts platform input through `PInputEventSink` and publishes a revisioned latest `InputSnapshot` through `PInputSnapshotSource`.
- The Simulation Runtime is authoritative for gameplay state and contains the engine, world, and ECS systems.
- Game Content supplies consumer-defined entities, world construction, presentation descriptions, and assets without becoming a runtime.
- ``World`` owns authoritative simulation state.
- ``Engine`` owns exact fixed-step execution and one complete ordered system schedule; cadence and pause policy exist only in App-owned drivers.
- ``PSystem`` implementations operate on component stores, not object facades, in hot paths.
- ``Entity`` subclasses and capability protocols remain the ergonomic game-facing layer.
- ``SimulationRuntime`` publishes its latest completed ``SimulationPresentationSnapshot``. The real-time screen uses that snapshot's camera exactly; it has no separately mutable viewpoint source.
- `InputMetalView` submits platform events directly to ``InputRuntime`` through `PInputEventSink`. ``MetalRenderer`` independently samples completed Simulation presentation and never interprets raw input.
- ``MetalFrameEncoder`` prepares and encodes the reusable Metal frame against caller-owned textures, frame resources, and a command buffer without depending on MetalKit view or drawable ownership.
- ``POffscreenRenderTarget`` accepts an exact immutable snapshot, explicit viewpoint, and render settings asynchronously. ``MetalOffscreenRenderRuntime`` implements that capability with dedicated one-slot Metal resources and returns detached pixels with exact request, scene, viewpoint, and settings provenance.
- ``RealtimeSnapshotCaptureConnection`` adapts the selected snapshot camera into the explicit viewpoint required by the offscreen contract. That value has one stable connection identity and revision zero; the connection owns no camera state and cannot diverge from its selected snapshot.
- ``PImageArtifactEncoder`` is the asynchronous transformation boundary above completed raw offscreen results. ``ImageIOArtifactEncoder`` is its stateless production implementation; it owns awaited detached CPU work for JPEG and PNG, preserves exact source and encoding provenance, and can be retried without advancing Simulation or rerendering.
- ``OffscreenImageArtifactDeriver`` composes exact rendering, complete result and cancellation correlation, and the selected artifact encoding without sampling or advancing Simulation.
- ``OfflineCaptureConfiguration`` composes one closed serial exact-scene/render/encode topology. Its assembly exposes only the initial cursor and ``POfflineCaptureTarget``, keeping ``OfflineCaptureCoordinator`` as the sole effective advance authority. The coordinator retains exactly the initial or last completed presentation and supports at-most-once advance capture plus mandatory-cursor current capture through one gate. It awaits the encoder-owned CPU work while preserving busy backpressure.
- ``AgentSessionConfiguration`` constructs an assembly that privately wraps the closed offline assembly behind ``PAgentSessionTarget``. ``AgentCaptureSource`` chooses bounded `.advance` or non-advancing `.current`, and the live-process coordinator places both complete payloads in one session-qualified monotonic at-most-once, exact-replay, typed-overlap, and drain-before-close lane without gaining a second advance or render capability.
This documentation catalog serves two purposes:
- document the behavior that already exists in the codebase
- capture architectural direction that is intentionally not implemented yet
At the moment, the codebase already includes:
- an App-owned Input Runtime whose immutable latest snapshot is captured by ``RealtimeAdvanceDriver`` and assigned to an exact Simulation request
- one complete ordered system schedule in ``Engine`` with semantic camera input mapping/control, input history/cleanup, and authoritative Simulation work
- an App-owned real-time driver that translates wall time into cursor-qualified exact requests, plus a clock-free ``ManualConfiguration``
- an app-facing ``SimulationRuntime`` that owns session bootstrap, serialized exact advancement, world construction policy, and completed publication
- a current real-time assembly whose `InputMetalView` feeds ``InputRuntime`` directly while a separate driver owns Simulation advancement
- a real-time screen path from ``SimulationPresentationSnapshot`` through `RenderFrame(projecting:)` and ``MetalSceneView`` that uses the published camera exactly, plus a separate exact request path through ``RenderViewpoint`` and `RenderFrame(exactlyProjecting:viewpoint:)`
- a view-independent production ``MetalFrameEncoder`` shared by the thin MetalKit screen adapter, the exact offscreen Runtime, and their render integration coverage
- a production exact offscreen request/outcome boundary with strict presentation/model/geometry preflight, configurable safety limits, single-flight backpressure, queue-feedback lifetime, cancellation semantics, and tightly packed top-left BGRA8-sRGB readback
- an asynchronous Image I/O artifact layer supporting validated JPEG quality and lossless PNG, with detached encoded data and exact request/cursor/viewpoint/render/encoding provenance
- a concrete serial offline capture configuration whose typed outcomes preserve either committed Simulation progress or the exact retained current presentation and, after rendering, the raw result needed for retryable artifact derivation
- a transport-neutral agent-session configuration whose closed assembly exposes only starting identity, ``PAgentSessionTarget``, and drain lifecycle; focused coverage validates both capture sources through one admission/idempotency/cache/cursor/cancellation/lifecycle policy, and real integration advances to tick one, captures and replays an alternate view at tick one, then advances to tick two

The obsolete `SimulationLoop`, elapsed-time Engine adapter, partial-schedule pause gate, and presentation-side camera bypass have been removed. ``SInputMapping`` and ``SCameraInput`` now form one focused Simulation-owned control path: imported pointer and scroll transients become semantic orbit/zoom commands, `World.camera` changes only within a complete tick, and the real-time screen observes that camera only after completed publication. Exact raw offscreen rendering, explicit request-carried viewpoints, CPU-side JPEG and PNG derivation, serial advance-or-current capture, and the live-process idempotent agent wrapper are implemented. The agent layer has no automatic cadence and preserves the offline coordinator as the only advance authority. Its current-cursor image artifact is visual output, not structured observation. An actual MCP Runtime or transport, authentication, wire DTOs, restart-safe idempotency journal, general physical or semantic gameplay controls, structured observations, persistence/sinks, dedicated render worker, pooled targets, atomic multi-view jobs, high-quality accumulation/HDR policy, additional artifact formats, typed routing, multi-window bindings, and observer anchors remain proposed; advancing agent requests currently assign `.none`.
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
