# Rendering Architecture

This article captures the intended rendering direction for Engine2.

## Status

Proposed. This design is not implemented yet.

## Runtime Truth Stays in ECS

Rendering should not become a second gameplay state model.

The authoritative simulation state should remain in ECS component stores. Render code should consume data extracted from ECS, not read or mutate gameplay state directly through entity objects during drawing.

## Render Extraction

The intended direction is to introduce a render extraction phase that reads ECS state and writes a flat list of render-facing structs.

Those structs should represent only the data needed to issue draw calls, such as:

- transform data
- mesh handle
- material handle
- render pipeline key
- sort or batch key
- any other renderer-facing flags needed for visibility, instancing, or ordering

These extracted values should be small, stable, and detached from gameplay-facing entity objects.

## Double-Buffered Render Data

The extracted render list should live in A/B buffers.

The intended model is:

1. simulation writes the next frame's render items into a back buffer
2. rendering reads the previously completed front buffer
3. the buffers swap once extraction is complete

This keeps rendering from reading partially updated simulation data and gives the engine a clean boundary between simulation work and render submission.

## Batching

Once render items are extracted, the renderer should be able to batch or sort them by renderer-relevant state.

The first useful batching keys are likely:

- render pipeline state
- material
- mesh

That keeps draw ordering decisions in the render pipeline instead of scattering them across gameplay objects.

## Resource Handles

ECS components should prefer stable renderer-facing handles or keys over raw Metal objects where practical.

For example, gameplay or extraction code can refer to a mesh ID, material ID, or pipeline key, and the renderer or render resource layer can resolve those IDs to actual Metal resources.

This keeps Metal-specific ownership and lifetime concerns inside the render layer.

## Intended Frame Shape

A likely long-term frame flow is:

1. simulation systems update ECS state
2. a render extraction phase reads ECS and writes render items
3. render items are sorted or batched
4. front and back render buffers swap
5. the renderer consumes the frozen front buffer

This is the intended path toward deterministic simulation, cleaner render isolation, and later optimizations such as culling and instancing.

## Related Direction

This rendering approach fits the broader engine direction:

- ``World`` remains the authoritative simulation container
- systems continue to operate on ECS data
- rendering consumes extracted frame data instead of live simulation objects

## Topics

### Related Symbols

- ``Engine``
- ``World``
- ``ComponentStore``
