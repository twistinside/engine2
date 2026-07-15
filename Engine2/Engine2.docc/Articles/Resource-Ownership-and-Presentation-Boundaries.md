# Resource Ownership and Presentation Boundaries
This article captures the intended boundary between simulation state, presentation state, and backend rendering state in Engine2.
See <doc:Runtime-Architecture> for the canonical top-level ownership model and runtime-boundary vocabulary.
See <doc:Runtime-Communication> for snapshot and event publication ownership.
See <doc:Game-Content-Architecture> for the distinction between packaged game assets, ECS resources, and runtime-owned backend resources.
## Status
Partially implemented.
The current code already reflects the core ownership split:
- ``World`` owns simulation-scoped state such as `camera` and `input`
- render-specific Metal objects remain owned by ``MetalRenderer``
- ``RenderFrame`` acts as the current translation boundary into presentation data
## Resource Scope Follows Runtime Ownership
Engine2 should treat `resource` as a storage, cardinality, and lifetime role inside an owning runtime, not as the primary naming vocabulary for every type.
Concrete types should still describe what they are responsible for, such as:
- `MetalContext`
- `RenderResourceCache`
- `MeshLibrary`
- `SpawnQueue`
- `DebugSettings`
The important questions are who owns the value, how long it lives, and whether it represents per-entity state. The number of systems that access a value does not determine whether it is a resource.
In practice:
- `World` can own simulation-scoped resources that affect gameplay or simulation behavior
- a runtime can own long-lived services and caches that never belong in `World`
- a data structure used only by one system can remain private system state
- long-lived shared storage written by one system and read by another can become a typed Simulation Runtime or World resource
- rendering types should keep backend-specific resources inside the Render Runtime
This lets the engine use resource storage patterns without collapsing every runtime into a single undifferentiated resource bag.

Do not connect runtimes through process-global mutable resources. Globals hide ownership, make multiple runtime instances difficult, contaminate tests, and make lifecycle and concurrency behavior implicit. The App should connect runtimes through explicit immutable boundary values.
## World Owns Abstract Presentation State
`World` is allowed to contain presentation-relevant state as long as that state remains abstract and engine-facing.
Examples of world-owned presentation data include:
- mesh handles
- material handles
- camera settings
- visibility flags
- render styles such as opaque, transparent, additive, or debug
That kind of data is still part of the game's authoritative state. It describes how an entity should appear, not how Metal happens to draw it.
What should not live in `World` are backend-specific objects such as:
- `MTLDevice`
- `MTLCommandQueue`
- `MTLRenderPipelineState`
- `MTLBuffer`
Those objects exist to satisfy rendering and should remain owned by the Render Runtime.
## The Render Runtime Owns Backend State
The Render Runtime is not the owner of gameplay truth.
It should own Metal-specific state and any caches or services that exist only to make draw submission work, including:
- device and queue setup
- pipeline compilation and caching
- GPU resource allocation
- pass configuration
- drawable or target encoding
This keeps backend lifetime concerns and platform-specific details isolated from simulation code.
## Extraction Is the Translation Boundary
The current code combines the simulation-to-render translation in ``RenderFrame.extract(from:)``. It reads abstract state from ``World`` and builds a flat immutable value that the renderer consumes.

The proposed runtime boundary separates publication from render projection:

1. the Simulation Runtime publishes a completed, backend-neutral `SimulationSnapshot`
2. the Render Runtime selects the latest value according to its own cadence
3. Render projects the fields it needs into a private `RenderFrame` or future render snapshot
4. Render resolves abstract identities into its privately owned backend resources

`World` should not directly emit Metal-facing structs as part of its core API, and the renderer should not read live gameplay state during drawing. The Render Runtime owns the destination projection while Simulation remains unaware of render-specific fields and backend choices.
## Draw Cadence Is Separate From Simulation Cadence
Simulation stepping and drawing should not be treated as the same event.
Under a fixed-step engine:
- simulation may advance zero, one, or multiple steps before a draw
- a draw may happen even when no new simulation tick has occurred
- presentation should consume the latest completed render data rather than reach back into live simulation state
In a Metal view-driven application, the view still dictates when a drawable is available. That should control when the renderer submits work, not when gameplay state advances.
The intended presentation model is:
1. simulation updates `World`
2. Simulation publishes a new immutable simulation snapshot
3. Render projects the latest available value into private render state
4. private front and back render frames swap
5. the Render Runtime draws from the latest completed value when presentation requests a draw
This keeps simulation deterministic while still fitting a display-driven render loop.
## Practical Naming Guidance
Prefer domain names for concrete types and reserve `PResource` for protocol or storage classification. Snapshot values use a descriptive `Snapshot` suffix rather than the `S` prefix, which remains reserved for ECS systems. Runtime types use the full `Runtime` suffix.
For example:
- prefer `MetalContext` over `RMetal`
- prefer `RenderResourceCache` over a generic render resource bag
- prefer `MeshLibrary` or `MaterialRepository` over unnamed storage wrappers
That keeps architectural intent readable while still allowing typed resource access patterns where they are useful.
## Related Direction
This boundary preserves the current engine direction:
- `World` remains authoritative for simulation and abstract presentation state
- ``PSystem`` implementations continue to operate on ECS data in hot paths
- the Simulation Runtime publishes its own observation snapshot without depending on a Render Runtime
- the Render Runtime owns a private projection of authoritative game state rather than a second gameplay model
## Topics
### Architecture
- <doc:Runtime-Architecture>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
### Related Symbols
- ``World``
- ``PResource``
