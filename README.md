# Engine2

Engine2 is a compact Swift experiment in building an ECS-first game engine without giving up an ergonomic, strongly typed game-object API.

The project is exploring a hybrid architecture:

- ECS component stores are the authoritative simulation state.
- Systems operate directly on component stores in hot paths.
- Typed `Entity` facades and capability protocols provide a convenient game-facing API.
- Input, simulation, and rendering live in independently owned runtimes connected through explicit snapshots and events.
- Consumer-defined Game Content supplies entities, world construction, presentation descriptions, and assets without owning runtime infrastructure.
- The App injects selected Game Content into one `PRuntimeAssembly` and presents the assembly as its SwiftUI root. Each assembly body owns any topology-specific presentation lifecycle.

Engine2 is early and intentionally small, but its architectural direction is documented as it develops.

## Documentation

Start with the [Engine2 DocC catalog](Engine2/Engine2.docc/Engine2.md), or jump directly to an architectural topic:

- [Runtime Architecture](Engine2/Engine2.docc/Articles/Runtime-Architecture.md) — runtime ownership, lifecycle, and cadence
- [Runtime Assemblies and Advancement](Engine2/Engine2.docc/Articles/Runtime-Assemblies-and-Advancement.md) — App hosting, topology construction, and exact advancement
- [Runtime Communication](Engine2/Engine2.docc/Articles/Runtime-Communication.md) — snapshots, events, and request/result workflows
- [Game Content Architecture](Engine2/Engine2.docc/Articles/Game-Content-Architecture.md) — the consumer-content boundary
- [Engine Architecture](Engine2/Engine2.docc/Articles/Engine-Architecture.md) — the ECS core and fixed-step simulation
- [System Scheduling](Engine2/Engine2.docc/Articles/System-Scheduling.md) — current scheduling and proposed future direction
- [Rendering Architecture](Engine2/Engine2.docc/Articles/Rendering-Architecture.md) — presentation snapshots and Metal rendering
- [Recorded Simulation and Render Workflows](Engine2/Engine2.docc/Articles/Recorded-Workflows.md) — file-backed replay, Render traces, and renderer-only benchmarking
- [Resource Ownership and Presentation Boundaries](Engine2/Engine2.docc/Articles/Resource-Ownership-and-Presentation-Boundaries.md) — ownership across simulation and rendering

The DocC pages distinguish between behavior that exists today and architecture proposed for future work.

## Open the project

Open [`Engine2.xcodeproj`](Engine2.xcodeproj) in Xcode. App source is under [`Engine2/`](Engine2), direct unit coverage is under [`Engine2UnitTests/`](Engine2UnitTests), and renderer integration coverage is under [`Engine2RenderTests/`](Engine2RenderTests).

## Measure headless Simulation performance

Select the shared `Headless Simulation` scheme and run it. The scheme builds the separate `HeadlessSimulation` command-line executable with Release optimization. Its thin entry point constructs `SimulationRuntime` directly through the same world-builder and configuration boundaries as the rendered application. An explicit positive source list excludes the app entry point, assemblies, UI, renderer implementation, render assets, and Metal sources. The backend-neutral `Camera` contract remains because Simulation snapshots require it.

The default workload constructs 100,000 moving and rotating `Ball` entities, warms up for 10 ticks, and measures 60 exact one-tick requests. Each sample includes the complete Simulation system schedule and one presentation publication. The console reports construction time, tick-duration percentiles, throughput, and a named 60 Hz wall-time reference.

Change the workload through the scheme's `ENGINE2_HEADLESS_ENTITY_COUNT`, `ENGINE2_HEADLESS_WARMUP_TICKS`, and `ENGINE2_HEADLESS_MEASURED_TICKS` environment variables. Each value must be a positive integer.

## Replay Simulation from a file

Select the shared `Simulation Replay` scheme and run it. The separate optimized `SimulationReplay` executable reads [`Fixtures/Simulation Replay/basic-game-v1.json`](Fixtures/Simulation%20Replay/basic-game-v1.json), constructs a fresh Simulation session, and applies each recorded exact Input assignment while producing its addressed completed tick. The optional initial baseline restores held Input without producing transients. A missing tick supplies `.none`, which applies no new assignment and does not clear previously held state.

The scheme also contains a disabled `--render-trace` argument pair. Enable both arguments to record every replayed presentation as semantic renderer input, or run the executable directly:

```text
SimulationReplay replay.json [--render-trace trace.json]
```

Replay schema version 1 starts from the selected Game Content's tick-zero world recipe. It is not a checkpoint or arbitrary seek format, and its original session identity is provenance rather than the identity of the fresh replay.

## Benchmark rendering from a file

Select the shared `Render Benchmark` scheme and run it. The separate optimized `RenderBenchmark` executable reads [`Fixtures/Render Trace/basic-game-v1.json`](Fixtures/Render%20Trace/basic-game-v1.json), preloads the Basic Game render catalog, and repeatedly encodes the trace through the production `MetalFrameEncoder`.

The benchmark requires a Metal 4 device, one homogeneous pixel size across the trace, complete catalog geometry, and no more than 256 presented instances per frame. The measured interval excludes file decoding, pipeline compilation, asset loading, target allocation, and warm-up. It includes renderer projection/preparation, command recording/submission, three-slot frame-ring back pressure, GPU execution, and final drain. The product creates no view, drawable, Input Runtime, Simulation Runtime, UI, or pixel readback, so it measures throughput rather than pixel correctness.

Pass optional whole-trace iteration counts after the file:

```text
RenderBenchmark trace.json [warm-up-iterations] [measured-iterations]
```

The warm-up count may be zero. The measured count must be positive.

## Status

Engine2 is an experimental, evolving codebase rather than a production-ready engine. The emphasis is on a coherent runtime model, strong domain types, explicit ownership boundaries, and a data-oriented simulation core.
