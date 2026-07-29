# Engine2

Engine2 is a compact Swift experiment in building an ECS-first game engine without giving up an ergonomic, strongly typed game-object API.

The project is exploring a hybrid architecture:

- ECS component stores are the authoritative simulation state.
- Systems operate directly on component stores in hot paths.
- Typed `Entity` facades and capability protocols provide a convenient game-facing API.
- Input, simulation, and rendering live in independently owned runtimes connected through explicit snapshots and events.
- Consumer-defined Game Content supplies entities, world construction, presentation descriptions, and assets without owning runtime infrastructure.

Engine2 is early and intentionally small, but its architectural direction is documented as it develops.

## Package layout

The Xcode application is a composition root over local Swift packages:

```text
Engine2App
├── Engine2AssemblySupport
│   └── Engine2
├── BasicGameContent
│   ├── Engine2AssemblySupport
│   └── Engine2
└── Engine2RealtimeAssembly
    ├── Engine2AssemblySupport
    └── Engine2
```

The repository also provides `Engine2ManualAssembly`,
`Engine2OfflineCaptureAssembly`, and `Engine2AgentSessionAssembly` as separate
products. The agent-session assembly depends on the offline-capture assembly
because it deliberately wraps that complete topology.

Each package boundary enforces an architectural dependency:

- [`Packages/Engine2/`](Packages/Engine2) contains reusable Input, Simulation,
  Render, ECS, and Metal implementation.
- [`Packages/BasicGameContent/`](Packages/BasicGameContent) contains the example
  entities, world builder, authored catalogs, and packaged model assets.
- [`Packages/AssemblySupport/`](Packages/AssemblySupport) contains the common
  `PRuntimeAssembly` App-hosting boundary plus the narrow `PGameContent`
  construction seam.
- [`Packages/RealtimeAssembly/`](Packages/RealtimeAssembly),
  [`Packages/ManualAssembly/`](Packages/ManualAssembly),
  [`Packages/OfflineCaptureAssembly/`](Packages/OfflineCaptureAssembly), and
  [`Packages/AgentSessionAssembly/`](Packages/AgentSessionAssembly) each contain
  one concrete Runtime Assembly and its topology-specific support.

Game Content owns exhaustive `MeshID` and `MaterialID` enums. It projects those
values into package-neutral `MeshAssetKey` and `MaterialAssetKey` values before
they enter engine-owned ECS, snapshot, or Render contracts. This keeps the
reusable engine independent of any consumer's closed asset vocabulary.
Concrete assemblies accept any `PGameContent` supplied by a consumer package;
they do not depend on `BasicGameContent`. The App constructs its selected Game
Content and injects it into the selected assembly.

## Documentation

Start with the [Engine2 DocC catalog](Packages/Engine2/Sources/Engine2/Engine2.docc/Engine2.md), or jump directly to an architectural topic:

- [Package Architecture](Packages/Engine2/Sources/Engine2/Engine2.docc/Articles/Package-Architecture.md) — enforced module and dependency boundaries
- [Runtime Architecture](Packages/Engine2/Sources/Engine2/Engine2.docc/Articles/Runtime-Architecture.md) — runtime ownership, lifecycle, and cadence
- [Runtime Communication](Packages/Engine2/Sources/Engine2/Engine2.docc/Articles/Runtime-Communication.md) — snapshots, events, and request/result workflows
- [Game Content Architecture](Packages/Engine2/Sources/Engine2/Engine2.docc/Articles/Game-Content-Architecture.md) — the consumer-content boundary
- [Engine Architecture](Packages/Engine2/Sources/Engine2/Engine2.docc/Articles/Engine-Architecture.md) — the ECS core and fixed-step simulation
- [System Scheduling](Packages/Engine2/Sources/Engine2/Engine2.docc/Articles/System-Scheduling.md) — current scheduling and proposed future direction
- [Rendering Architecture](Packages/Engine2/Sources/Engine2/Engine2.docc/Articles/Rendering-Architecture.md) — presentation snapshots and Metal rendering
- [Resource Ownership and Presentation Boundaries](Packages/Engine2/Sources/Engine2/Engine2.docc/Articles/Resource-Ownership-and-Presentation-Boundaries.md) — ownership across simulation and rendering

The DocC pages distinguish between behavior that exists today and architecture proposed for future work.

## Open the project

Open [`Engine2.xcodeproj`](Engine2.xcodeproj) in Xcode. The thin App composition
root and asset catalog are under [`Engine2/`](Engine2), reusable production
source is under [`Packages/`](Packages), direct unit coverage is under
[`Engine2UnitTests/`](Engine2UnitTests), and renderer integration coverage is
under [`Engine2RenderTests/`](Engine2RenderTests).

## Status

Engine2 is an experimental, evolving codebase rather than a production-ready engine. The emphasis is on a coherent runtime model, strong domain types, explicit ownership boundaries, and a data-oriented simulation core.
