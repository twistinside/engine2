# Rendering Architecture
This article captures the intended rendering direction for Engine2.
## Status
Partially implemented.
The current codebase already has:
- ``RenderFrame.extract(from:)`` as an early combined simulation-extraction and render-snapshot path
- ``MetalSceneView`` as the SwiftUI/MetalKit bridge
- ``MetalRenderer`` as the backend-specific Metal 4 renderer
- a typed `MeshID` and `RenderAssetCatalog` boundary between Game Content and renderer-owned resources
The broader ideas below describe where that path is expected to grow.
See <doc:Runtime-Architecture> for the canonical Runtime, Snapshot, Event, and runtime-boundary vocabulary.
See <doc:Runtime-Communication> for the proposed publisher-owned snapshot and consumer-owned projection model.
## Rendering Belongs to the Render Runtime
Rendering is owned by the proposed Render Runtime, not by an ECS gameplay system that mutates authoritative state.
Simulation systems update `World`, the Simulation Runtime publishes an immutable `SimulationSnapshot`, and the Render Runtime projects the latest completed value into private render-oriented state according to its own cadence. The Simulation Runtime remains valid when no Render Runtime is present; its snapshot simply has no render consumer.
## Simulation Truth Stays in ECS
Rendering should not become a second gameplay state model.
The authoritative simulation state should remain in ECS component stores. Render code should consume a completed `SimulationSnapshot`, not read or mutate gameplay state directly through entity objects during drawing.
`World` may still contain abstract presentation state such as mesh handles, material handles, visibility, camera settings, and render style. What it should not contain are backend-specific Metal objects.

The current `CRenderable` component demonstrates that distinction. It stores a
`MeshID`, while `BasicGameContent` maps `MeshID.ball` to the packaged
`Ball.usdz` asset. ``MetalRenderer`` receives that catalog and privately owns
the decoded meshes, buffers, and residency sets.
## Rendering Projects Published Simulation State
Today, ``RenderFrame.extract(from:)`` reads the subset of ``World`` state needed by the current renderer: camera plus renderable entities' mesh identity, position, optional rotation, and optional scale. Positioned entities without `CRenderable` presentation state are deliberately excluded. This remains a compact implemented shortcut that combines source access with render-oriented projection.

The proposed runtime boundary separates those responsibilities:

- `World` remains private authoritative simulation state
- the Simulation Runtime publishes a completed, backend-neutral `SimulationSnapshot`
- the Render Runtime selects and projects the fields it needs
- the renderer consumes its private render snapshot and backend resources

This accepts that an explicitly connected Render Runtime can observe fields in `SimulationSnapshot` that it does not currently use. It still cannot mutate simulation state, inspect ECS storage machinery, or access `World` directly.
## Render Extraction
The current renderer already consumes a flat `RenderFrame` of `RenderInstance` values extracted from ECS state. `RenderFrame` currently serves as the private render-oriented snapshot while its `extract(from:)` implementation also reaches directly into the simulation source.

The intended direction is for Render to construct that private value from `SimulationSnapshot` instead. The projection is render-owned because only Render knows which destination fields and derived values it needs. The exact future type name and API are not yet selected; do not treat `RenderSnapshot` or a general projection protocol as implemented types.

The render-oriented structs may grow to represent only the data needed to issue draw calls, such as:
- transform data
- mesh handle
- material handle
- render pipeline key
- sort or batch key
- any other renderer-facing flags needed for visibility, instancing, or ordering
These projected values should be small, stable, and detached from gameplay-facing entity objects.
The important boundary is that Simulation publishes completed observable facts while Render defines its private frame format.
## Snapshot Publication and Storage
The current path does not yet have an explicit simulation-snapshot publication exchange or A/B `RenderFrame` buffers.
Those remain intended boundaries once presentation data grows beyond the current simple extraction closure.
The intended model is:
1. Simulation publishes a completed `SimulationSnapshot` through a latest-value boundary
2. Render selects the latest available simulation snapshot when it is ready
3. Render projects that source value into its private render snapshot or back buffer
4. Render presents from the latest completed private value

This keeps rendering from reading partially updated simulation data and allows it to skip superseded simulation snapshots. Snapshot exchange and private render buffering may use latest slots, front/back values, or short rings; the exact mechanism remains future work.
## Draws Follow Presentation Cadence
Drawing should be allowed to happen on a different cadence from simulation ticking.
In practice, a Metal view or display callback will dictate when a draw can occur because it provides the current drawable. That should drive presentation timing, not gameplay authority.
The intended model is:
- fixed-step simulation updates `World`
- Simulation publishes a completed simulation snapshot
- Render projects the latest available value into render data
- rendering consumes the latest completed front buffer when a draw is requested
This allows zero, one, or many simulation ticks between draws without making draw cadence the owner of simulation state.

Rendering is snapshot-only. It does not rely on receiving simulation events. A transient visual occurrence must therefore remain represented in snapshot-visible presentation state long enough for a renderer that skips intermediate snapshots to observe or converge past it correctly.
## Batching
Once render items are extracted, the renderer should be able to batch or sort them by renderer-relevant state.
The first useful batching keys are likely:
- render pipeline state
- material
- mesh
That keeps draw ordering decisions in the render pipeline instead of scattering them across gameplay objects.
Gameplay state can still influence the eventual pipeline choice through abstract render style or material data. The Render Runtime's projection and resource layers are responsible for resolving that abstract intent into concrete pipeline keys and backend objects.
## Resource Handles
ECS components should prefer stable renderer-facing handles or keys over raw Metal objects where practical.
For example, gameplay code can refer to a mesh ID, material ID, visibility flag, or render style, and the Render Runtime can project and resolve those values to actual pipeline keys and Metal resources.
This keeps Metal-specific ownership and lifetime concerns inside the render layer.
The identities, presentation descriptions, and source assets that differentiate a particular game belong to Game Content. The Render Runtime receives the relevant catalogs during App construction and privately resolves them into backend resources. See <doc:Game-Content-Architecture>.
## Intended Frame Shape
A likely long-term frame flow is:
1. simulation systems update ECS state
2. the Simulation Runtime publishes a completed `SimulationSnapshot`
3. the Render Runtime projects the latest simulation state into render items
4. render items are sorted or batched
5. private front and back render buffers swap
6. the renderer consumes the frozen front buffer
This is the intended path toward deterministic simulation, cleaner render isolation, and later optimizations such as culling and instancing.
## Related Direction
This rendering approach fits the broader engine direction:
- ``World`` remains the authoritative simulation container
- ``PSystem`` implementations continue to operate on ECS data
- the Simulation Runtime publishes its own observation snapshot without requiring a Render Runtime
- the Render Runtime projects published state instead of reading live simulation objects
## Topics
### Architecture
- <doc:Runtime-Architecture>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
### Related Symbols
- ``Engine``
- ``PResource``
- ``World``
- ``ComponentStore``
