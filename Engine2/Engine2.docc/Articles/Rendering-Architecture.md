# Rendering Architecture
This article captures the intended rendering direction for Engine2.
## Status
Partially implemented.
The current codebase already has:
- ``RenderFrame.extract(from:)`` as the first implemented simulation-to-render snapshot boundary
- ``MetalSceneView`` as the SwiftUI/MetalKit bridge
- ``MetalRenderer`` as the backend-specific Metal 4 renderer
The broader ideas below describe where that path is expected to grow.
See <doc:Runtime-Architecture> for the canonical Runtime, Snapshot, Event, and runtime-boundary vocabulary.
## Rendering Belongs to the Render Runtime
Rendering is owned by the proposed Render Runtime, not by an ECS gameplay system that mutates authoritative state.
Simulation systems update `World`, an extraction phase publishes immutable presentation state, and the Render Runtime consumes the latest completed snapshot according to its own cadence. The Simulation Runtime remains valid when no Render Runtime is present; its render output simply goes unobserved.
## Simulation Truth Stays in ECS
Rendering should not become a second gameplay state model.
The authoritative simulation state should remain in ECS component stores. Render code should consume data extracted from ECS, not read or mutate gameplay state directly through entity objects during drawing.
`World` may still contain abstract presentation state such as mesh handles, material handles, visibility, camera settings, and render style. What it should not contain are backend-specific Metal objects.
## Extraction Reads a Narrow Render View
The render extraction boundary should depend on only the subset of simulation state required for presentation.
Today, ``RenderFrame.extract(from:)`` reads the subset of ``World`` state needed by the current renderer: camera, position, optional rotation, and optional scale.
The intended direction is to keep that extraction narrow, potentially through a more explicit read model such as `RenderWorldView`, rather than unrestricted renderer access to all engine state.
That keeps the dependency direction clear:
- `World` remains authoritative for abstract state
- extraction translates abstract state into renderer-facing frame data
- the renderer consumes frame data and backend resources
## Render Extraction
The current renderer already consumes a flat `RenderFrame` of `RenderInstance` values extracted from ECS state. `RenderFrame` currently serves the role described architecturally as a render snapshot. A future explicit runtime boundary may adopt the name `RenderSnapshot`; do not treat that proposed name as an already implemented type.
The intended next step is to expand that extraction phase so it can read richer abstract presentation state and write a broader set of renderer-facing structs.
Those structs should represent only the data needed to issue draw calls, such as:
- transform data
- mesh handle
- material handle
- render pipeline key
- sort or batch key
- any other renderer-facing flags needed for visibility, instancing, or ordering
These extracted values should be small, stable, and detached from gameplay-facing entity objects.
The important boundary is that `World` provides the state that should be rendered, while extraction defines the renderer-facing frame format.
## Snapshot Publication and Storage
The extracted render list does not yet live in explicit A/B `RenderFrame` buffers.
That remains the intended next boundary once presentation data grows beyond the current simple extraction closure.
The intended model is:
1. simulation writes the next frame's render items into a back buffer
2. rendering reads the previously completed front buffer
3. the buffers swap once extraction is complete
This keeps rendering from reading partially updated simulation data and creates a clean runtime boundary between simulation work and render submission. The storage mechanism may use front/back slots or a ring internally; its boundary value remains an immutable render snapshot rather than a Metal buffer.
## Draws Follow Presentation Cadence
Drawing should be allowed to happen on a different cadence from simulation ticking.
In practice, a Metal view or display callback will dictate when a draw can occur because it provides the current drawable. That should drive presentation timing, not gameplay authority.
The intended model is:
- fixed-step simulation updates `World`
- extraction prepares the next back buffer of render data
- rendering consumes the latest completed front buffer when a draw is requested
This allows zero, one, or many simulation ticks between draws without making draw cadence the owner of simulation state.
## Batching
Once render items are extracted, the renderer should be able to batch or sort them by renderer-relevant state.
The first useful batching keys are likely:
- render pipeline state
- material
- mesh
That keeps draw ordering decisions in the render pipeline instead of scattering them across gameplay objects.
Gameplay state can still influence the eventual pipeline choice through abstract render style or material data. The renderer or extraction phase is responsible for resolving that abstract intent into concrete pipeline keys and backend objects.
## Resource Handles
ECS components should prefer stable renderer-facing handles or keys over raw Metal objects where practical.
For example, gameplay code can refer to a mesh ID, material ID, visibility flag, or render style, and the extraction or render resource layer can resolve those values to actual pipeline keys and Metal resources.
This keeps Metal-specific ownership and lifetime concerns inside the render layer.
The identities, presentation descriptions, and source assets that differentiate a particular game belong to Game Content. The Render Runtime receives the relevant catalogs during App construction and privately resolves them into backend resources. See <doc:Game-Content-Architecture>.
## Intended Frame Shape
A likely long-term frame flow is:
1. simulation systems update ECS state
2. a render extraction phase reads abstract presentation state and writes render items
3. render items are sorted or batched
4. front and back render buffers swap
5. the renderer consumes the frozen front buffer
This is the intended path toward deterministic simulation, cleaner render isolation, and later optimizations such as culling and instancing.
## Related Direction
This rendering approach fits the broader engine direction:
- ``World`` remains the authoritative simulation container
- ``PSystem`` implementations continue to operate on ECS data
- the Simulation Runtime publishes extracted snapshot data without requiring a Render Runtime
- the Render Runtime consumes extracted data instead of live simulation objects
## Topics
### Architecture
- <doc:Runtime-Architecture>
- <doc:Game-Content-Architecture>
### Related Symbols
- ``Engine``
- ``PResource``
- ``World``
- ``ComponentStore``
