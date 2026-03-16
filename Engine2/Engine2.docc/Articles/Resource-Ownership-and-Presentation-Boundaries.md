# Resource Ownership and Presentation Boundaries

This article captures the intended boundary between simulation state, presentation state, and backend rendering state in Engine2.

## Status

Proposed. This design is not implemented yet.

## Resource Scope Follows Ownership

Engine2 should treat `resource` as a storage and lifetime role, not as the primary naming vocabulary for every type.

Concrete types should still describe what they are responsible for, such as:

- `MetalContext`
- `RenderResourceCache`
- `MeshLibrary`
- `SpawnQueue`
- `DebugSettings`

The important question is who owns the value and how broadly it must be shared.

In practice:

- `World` can own simulation-scoped resources that affect gameplay or simulation behavior
- engine subsystems can own their own long-lived services and caches
- rendering types should keep backend-specific resources inside the render layer

This lets the engine use resource storage patterns without collapsing every subsystem into a single undifferentiated resource bag.

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

Those objects exist to satisfy the renderer and should remain renderer-owned.

## Renderer Owns Backend State

Rendering is a first-class engine subsystem, but it is not the owner of gameplay truth.

The renderer should own Metal-specific state and any caches or services that exist only to make draw submission work, including:

- device and queue setup
- pipeline compilation and caching
- GPU resource allocation
- pass configuration
- drawable or target encoding

This keeps backend lifetime concerns and platform-specific details isolated from simulation code.

## Extraction Is the Translation Boundary

The clean boundary between simulation and rendering is an extraction or export phase.

That phase should:

1. read the world's abstract presentation state
2. build a flat, renderer-facing `RenderFrame`
3. hand that frozen frame to the renderer

`World` should not directly emit Metal-facing structs as part of its core API, and `Renderer` should not read arbitrary gameplay state during drawing.

The intended direction is a narrow render-facing read model derived from `World`, such as a `RenderWorldView` or other extraction source. That keeps rendering dependent on only the data it actually needs while leaving `World` free of renderer-specific API surface.

## Draw Cadence Is Separate From Simulation Cadence

Simulation stepping and drawing should not be treated as the same event.

Under a fixed-step engine:

- simulation may advance zero, one, or multiple steps before a draw
- a draw may happen even when no new simulation step has occurred
- presentation should consume the latest completed render data rather than reach back into live simulation state

In a Metal view-driven application, the view still dictates when a drawable is available. That should control when the renderer submits work, not when gameplay state advances.

The intended presentation model is:

1. simulation updates `World`
2. extraction writes a back `RenderFrame`
3. front and back render frames swap
4. the renderer draws from the frozen front frame when presentation requests a draw

This keeps simulation deterministic while still fitting a display-driven render loop.

## Practical Naming Guidance

Prefer domain names for concrete types and reserve `Resource` for protocol or storage classification.

For example:

- prefer `MetalContext` over `RMetal`
- prefer `RenderResourceCache` over a generic render resource bag
- prefer `MeshLibrary` or `MaterialRepository` over unnamed storage wrappers

That keeps architectural intent readable while still allowing typed resource access patterns where they are useful.

## Related Direction

This boundary preserves the current engine direction:

- `World` remains authoritative for simulation and abstract presentation state
- systems continue to operate on ECS data in hot paths
- rendering stays an engine subsystem without becoming a second gameplay model

## Topics

### Related Symbols

- ``World``
- ``Resource``
