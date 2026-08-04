# Recorded Simulation and Render Workflows

Replay files reproduce Simulation Input assignments, while Render traces
reproduce semantic Render input. Keeping the two contracts separate lets each
workflow retain the exact facts its authority consumes.

## Replay Simulation from Exact Input Assignments

``SimulationReplayFile`` is the versioned durable contract for one finite
Simulation replay. Its entries address the completed tick that consumes an exact
``SimulationInputAssignment``. The optional initial Input baseline restores
held state without deriving transients. A missing tick entry means `.none`; it
supplies no new assignment and does not clear held state. The format does not
persist redundant `.none` records.

``SimulationReplayDriver`` validates the file's
``RecordingContentIdentifier``, constructs a fresh ``SimulationRuntime`` from
the caller's world builder and configuration, and submits one cursor-qualified
one-tick request for every tick through the terminal tick. The recorded session
identity remains provenance. The fresh Runtime owns a new session identity.

The result retains the fresh tick-zero presentation and every exact completed
``SimulationPresentationSnapshot`` in order. A caller can inspect those values,
compare them with a reference, or record them as Render input without exposing
the live ``World``.

Schema version 1 deliberately starts from the content's tick-zero world recipe.
It does not restore arbitrary checkpoints, random-number state, or external
service results. Stable ordering, seeded randomness, content compatibility, and
floating-point policy remain necessary when a game requires stronger
cross-machine determinism.

## Record Semantic Render Input

``RenderTrace`` stores the semantic input needed to reproduce Render work:

- the complete Simulation presentation and its cursor
- either the recorded Simulation camera or one explicit ``RenderViewpoint``
- pixel size, output mode, exposure, and clear color
- ordered frame identity plus trace and content compatibility identity

A `.simulationCamera` frame resolves the recorded snapshot camera under the
header's stable viewpoint identity at revision zero. An `.explicit` frame
preserves its own viewpoint identity, revision, and camera.

The trace does not store pixels, private ``RenderFrame`` values, decoded assets,
Metal objects, or CPU/GPU ABI records. ``RenderTraceJSONWriter`` records the
versioned JSON contract, and ``RenderTraceJSONReader`` rejects unsupported
versions and malformed values before reconstructing trusted domain input.
The command host separately checks the trace's content compatibility identity
against the selected Game Content.

A Simulation replay can create a trace from its ordered presentation result.
Render can later consume that file without constructing an Input Runtime,
Simulation Runtime, assembly, or view.

## Benchmark Only the Renderer

The separate `RenderBenchmark` command-line product reads one ``RenderTrace``
and constructs only the content descriptions and Render implementation required
to encode it. ``RenderBenchmarkRunner`` uses the production
``MetalFrameEncoder`` with a three-slot resource ring and preallocated private
HDR, depth, and destination targets. It creates no drawable, screen, Input
Runtime, Simulation Runtime, assembly, or pixel readback.

File decoding, pipeline compilation, asset loading, and target allocation finish
before warm-up. Warm-up iterations drain before the measured interval. The
result reports:

- end-to-end wall throughput, including frame-ring back pressure and final drain
- CPU projection and preparation duration
- CPU command recording and submission duration
- GPU execution duration from Metal 4 queue feedback

These measurements describe offscreen renderer throughput for the recorded
workload. They do not include display presentation, drawable acquisition, image
encoding, artifact storage, or pixel correctness validation. The benchmark
requires a Metal 4 device and rejects traces whose frames use different pixel
sizes because every frame slot preallocates one target size. A valid trace may
otherwise carry different settings per frame. Every frame must also reference
complete catalog geometry and fit the current 256-instance capacity.

## Current Storage Limits

Schema version 1 is an in-memory whole-file workflow. Each reader decodes its
complete JSON value. Replay retains tick zero plus every completed presentation,
and the benchmark command host converts and preloads every trace frame before
warm-up. The formats are not streaming contracts.

No current Input or Realtime Runtime records a live player session
automatically. Checkpoint seeking, rollback, continuous Input-transition
recording, streaming traces, and pixel-output traces remain future work.

## Run the Example Workflows

The shared `Simulation Replay` scheme reads the committed Basic Game replay
fixture. Enable its disabled `--render-trace` argument pair to write a new trace,
or invoke the product directly:

```text
SimulationReplay replay.json [--render-trace trace.json]
```

The shared `Render Benchmark` scheme reads the committed trace and runs one
warm-up plus five measured workload iterations. Its command-line form is:

```text
RenderBenchmark trace.json [warm-up-iterations] [measured-iterations]
```

The warm-up count must be nonnegative. The measured count must be positive.

Both files carry ``BasicGameRecording/contentIdentifier``. Game Content must
change that identifier whenever its tick-zero recipe, Simulation policy,
identity vocabulary, or required assets become incompatible with an older
recording.

## Related Architecture

- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Engine-Architecture>
- <doc:Game-Content-Architecture>
- <doc:Rendering-Architecture>
