# Engine2

Engine2 is a compact Swift experiment in building an ECS-first game engine without giving up an ergonomic, strongly typed game-object API.

The project is exploring a hybrid architecture:

- ECS component stores are the authoritative simulation state.
- Systems operate directly on component stores in hot paths.
- Authoritative translation and fixed-step seconds use `Double`; completed presentation snapshots narrow positions to
  `Float` for rendering.
- Explicit schedules can place `SGravity` before `SMovement`, so collective gravity uses the existing motion accumulator
  and movement authority. Production waits for collision handling and an expected Simulation failure outcome before it
  installs gravity.
- Typed `Entity` facades and capability protocols provide a convenient game-facing API.
- Input, simulation, and rendering live in independently owned runtimes connected through explicit snapshots and events.
- Consumer-defined Game Content supplies entities, world construction, presentation descriptions, and assets without owning runtime infrastructure.
- Versioned procedural star-system generation resolves physical Game Content before ECS, gameplay, or rendering consumes it.
- The App injects selected Game Content into one `PRuntimeAssembly` and presents the assembly as its SwiftUI root. Each assembly body owns any topology-specific presentation lifecycle.

Engine2 is early and intentionally small, but its architectural direction is documented as it develops.

## Documentation

Start with the [Engine2 DocC catalog](Engine2/Engine2.docc/Engine2.md), or jump directly to an architectural topic:

- [Runtime Architecture](Engine2/Engine2.docc/Articles/Runtime-Architecture.md) — runtime ownership, lifecycle, and cadence
- [Runtime Assemblies and Advancement](Engine2/Engine2.docc/Articles/Runtime-Assemblies-and-Advancement.md) — App hosting, topology construction, and exact advancement
- [Runtime Communication](Engine2/Engine2.docc/Articles/Runtime-Communication.md) — snapshots, events, and request/result workflows
- [Game Content Architecture](Engine2/Engine2.docc/Articles/Game-Content-Architecture.md) — the consumer-content boundary
- [Star System Generation](Engine2/Engine2.docc/Articles/Star-System-Generation.md) — deterministic disk, planet, residual-body, encounter, atmosphere, and moon generation with explicit conservation destinations
- [Star System Generation Calibration](Engine2/Engine2.docc/Articles/Star-System-Generation-Calibration.md) — exact V1 distributions, equations, bounded fallbacks, audit policy, and limitations
- [Engine Architecture](Engine2/Engine2.docc/Articles/Engine-Architecture.md) — the ECS core and fixed-step simulation
- [System Scheduling](Engine2/Engine2.docc/Articles/System-Scheduling.md) — current scheduling and proposed future direction
- [Rendering Architecture](Engine2/Engine2.docc/Articles/Rendering-Architecture.md) — presentation snapshots and Metal rendering
- [Resource Ownership and Presentation Boundaries](Engine2/Engine2.docc/Articles/Resource-Ownership-and-Presentation-Boundaries.md) — ownership across simulation and rendering

The DocC pages distinguish between behavior that exists today and architecture proposed for future work.

## Open the project

Open [`Engine2.xcodeproj`](Engine2.xcodeproj) in Xcode. App source is under [`Engine2/`](Engine2), direct unit coverage is under [`Engine2UnitTests/`](Engine2UnitTests), and renderer integration coverage is under [`Engine2RenderTests/`](Engine2RenderTests).

## Explore generated star systems

Select the shared `StarSystemExplorer` scheme and run the macOS app. Enter a decimal `UInt64` seed or a hexadecimal value with a `0x` prefix, then choose **Generate**. The explorer presents the host star, protoplanetary disk, selectable linear or zero-safe logarithmic orbital architecture, conserved formation ledger, resolved planets, nested moons, environments, compositions, classifications, and stored model policy.

The explorer compiles the star-system generator's closed source set directly into its own target. It does not construct a Runtime Assembly, ECS world, renderer, or Metal resources. Its focused `StarSystemExplorerTests` target covers seed parsing, logarithmic orbit placement, generator integration, and valid zero-planet output.

## Measure headless Simulation performance

Select the shared `Headless Simulation` scheme and run it. The scheme builds the separate `HeadlessSimulation` command-line executable with Release optimization. Its thin entry point constructs `SimulationRuntime` directly through the same world-builder and configuration boundaries as the rendered application. An explicit positive source list excludes the app entry point, assemblies, UI, renderer implementation, render assets, and Metal sources. The backend-neutral `Camera` contract remains because Simulation snapshots require it.

The default workload constructs 100,000 moving and rotating `Ball` entities, warms up for 10 ticks, and measures 60 exact one-tick requests. Each sample includes the complete Simulation system schedule and one presentation publication. The console reports construction time, tick-duration percentiles, throughput, and a named 60 Hz wall-time reference.

Change the workload through the scheme's `ENGINE2_HEADLESS_ENTITY_COUNT`, `ENGINE2_HEADLESS_WARMUP_TICKS`, and `ENGINE2_HEADLESS_MEASURED_TICKS` environment variables. Each value must be a positive integer.

## Status

Engine2 is an experimental, evolving codebase rather than a production-ready engine. The emphasis is on a coherent runtime model, strong domain types, explicit ownership boundaries, and a data-oriented simulation core.
