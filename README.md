# Engine2

Engine2 is a compact Swift experiment in building an ECS-first game engine without giving up an ergonomic, strongly typed game-object API.

The project is exploring a hybrid architecture:

- ECS component stores are the authoritative simulation state.
- Systems operate directly on component stores in hot paths.
- Typed `Entity` facades and capability protocols provide a convenient game-facing API.
- Input, simulation, and rendering live in independently owned runtimes connected through explicit snapshots and events.
- Consumer-defined Game Content supplies entities, world construction, presentation descriptions, and assets without owning runtime infrastructure.

Engine2 is early and intentionally small, but its architectural direction is documented as it develops.

## Documentation

Start with the [Engine2 DocC catalog](Engine2/Engine2.docc/Engine2.md), or jump directly to an architectural topic:

- [Runtime Architecture](Engine2/Engine2.docc/Articles/Runtime-Architecture.md) — runtime ownership, lifecycle, and cadence
- [Runtime Communication](Engine2/Engine2.docc/Articles/Runtime-Communication.md) — snapshots, events, and request/result workflows
- [Game Content Architecture](Engine2/Engine2.docc/Articles/Game-Content-Architecture.md) — the consumer-content boundary
- [Engine Architecture](Engine2/Engine2.docc/Articles/Engine-Architecture.md) — the ECS core and fixed-step simulation
- [System Scheduling](Engine2/Engine2.docc/Articles/System-Scheduling.md) — current scheduling and proposed future direction
- [Rendering Architecture](Engine2/Engine2.docc/Articles/Rendering-Architecture.md) — presentation snapshots and Metal rendering
- [Resource Ownership and Presentation Boundaries](Engine2/Engine2.docc/Articles/Resource-Ownership-and-Presentation-Boundaries.md) — ownership across simulation and rendering

The DocC pages distinguish between behavior that exists today and architecture proposed for future work.

## Open the project

Open [`Engine2.xcodeproj`](Engine2.xcodeproj) in Xcode. The app source is under [`Engine2/Engine2`](Engine2/Engine2), with mirrored Swift Testing coverage under [`Engine2/Engine2Tests`](Engine2/Engine2Tests).

## Status

Engine2 is an experimental, evolving codebase rather than a production-ready engine. The emphasis is on a coherent runtime model, strong domain types, explicit ownership boundaries, and a data-oriented simulation core.
