# Engine Architecture

Engine2 keeps fixed-step execution, authoritative ECS state, system logic, and
entity facades separate inside ``SimulationRuntime``. See
<doc:Runtime-Architecture> for top-level Runtime ownership and
<doc:Runtime-Assemblies-and-Advancement> for the exact-advance boundary.

## Current Simulation Roles

### Engine

``Engine`` owns exact fixed-step execution and one ordered system list.
``Engine/step(inputSnapshot:)`` optionally ingests one ``InputSnapshot``, runs
the complete list in declaration order, and advances the completed tick once.
It does not sample a clock, accumulate elapsed time, or run a partial schedule.

Request-level input policy belongs to ``SimulationRuntime``. The Runtime
applies any rebase and passes an ingest snapshot only to the first Engine step
of an accepted batch. ``RealtimeAdvanceDriver`` owns wall-time accumulation and
pause policy; neither concern enters ``Engine``.

Production construction receives one validated ``SimulationConfiguration`` and
one ``SimulationBehavior``. The Engine builds its invariant camera-input,
acceleration-intent, movement, rotation, and input-cleanup systems. It inserts
the behavior's ``SimulationSystemSchedule`` systems only at the named
`inputConsumption`, `worldPreparation`, `forceContribution`, `postMovement`,
and `prePresentation` stages. ``SimulationConfiguration`` supplies the camera
policy. Physical bindings and input sensitivity remain
``InputMappingConfiguration`` policy owned by the Input Runtime.

The complete injected-systems initializer remains available for focused
integration tests. Callers of that initializer must supply the ``World``, fixed
step, and entire system list explicitly.

### Simulation Runtime and World Builders

``SimulationRuntime`` owns one authoritative session, its ``Engine``, world
construction, serialized exact advancement, and publication of committed
results. Construction requires a ``WorldBuilder``,
``SimulationConfiguration``, an explicit input baseline, and either an explicit
or newly generated ``SimulationSessionID``. It accepts a
``SimulationBehavior`` and defaults to ``StandardSimulationBehavior``.

The Runtime can rebuild the active world from its retained builder, replace the
builder used by a later rebuild, or replace the builder and rebuild immediately.
Each rebuild begins a new session at tick zero and publishes its initial
presentation. Its ``SimulationAdvanceTarget`` capability validates an optional
expected ``SimulationCursor`` before applying input or a maneuver command,
executes the requested number of complete steps, and returns a cursor-correlated
result.

Cadence remains outside this boundary. Deterministic tests can issue exact
requests without a clock or Input Runtime. The real-time assembly instead uses
``RealtimeAdvanceDriver`` to translate wall time and latest input into those
same requests.

``WorldBuilder`` is a one-shot Simulation-owned construction interface, not a
simulation ``System``. A builder returns a fully bootstrapped ``World`` before
the Runtime begins or rebuilds a session. Game Content supplies the conforming
builder; the Runtime does not discover content through a global registry. See
<doc:Game-Content-Architecture>.

### World

``World`` owns authoritative component stores, simulation-scoped resources,
``EntityID`` allocation, and the live-facade registry. It is not the scheduler and
does not decide when Simulation advances.

Concrete entity constructors assemble one `Entity.InitialState` containing
authored spawn facts: scalar and SIMD values, enums, typed identities, and
grouped descriptions such as ``CollisionBodyInitialState`` and
``OrbitalRailInitialState``. Initial state contains no component instances.
``World/add(_:from:)`` validates the facts against advertised capabilities,
constructs the components, and performs every construction-time store write.

The World derives capability markers and neutral player control from the
facade's conformances. Every collision body receives a previous position equal
to its resolved spawn position. Depot delivery totals start at zero, and a
missile's remaining lifetime starts from its authored flight duration.

An ``Orbiting`` entity describes placement through one rail seed:

```swift
let initialState = Entity.InitialState(
    orbitalRail: OrbitalRailInitialState(
        primaryEntityID: star.id,
        radius: 1_800,
        angularSpeed: 0.001,
        phase: 0.35
    )
)
```

The World resolves the complete primary identity to a live positioned entity,
then derives the rail's initial position and velocity. A missing, stale, or
nonfinite primary position fails registration. An orbital rail cannot be
combined with explicit position or translational motion seeds. Game Content
therefore supplies neither a duplicate primary position nor a calculated rail
position.

Registration returns a complete entity ready for the initial presentation.
Systems evolve that state on later ticks; no bootstrap tick repairs an
incomplete spawn.

Capability composition supplies shared invariants. ``Renderable`` refines
``Positionable``. ``Selectable`` refines ``Positionable`` and requires a
selection row plus a positive spherical hit bound. ``Interactable`` refines
``Positionable`` and requires one positive proximity range.

``EntityID`` compares index first and generation second. This structural order
provides deterministic enumeration and equal-result tie-breaking; it does not
encode distance, age, or gameplay priority. Lookup and equality preserve the
complete identity, including generation.

``World/destroy(_:)`` removes a registered facade and all its component rows,
then clears selection, camera follow, and any pending orbit command targeting
that identity. Unknown or stale identities leave the World unchanged.
``ComponentStore/remove(for:)`` compacts dense storage and repairs the moved
row's sparse lookup. Existing presentation snapshots remain unchanged; the next
completed snapshot omits destroyed entities. First registration requires an
outstanding World reservation, so a destroyed facade cannot register again.

Systems collect structural work before applying it. A launch system constructs
typed entities through ``World/add(_:from:)`` after collecting its launch
requests; an impact system collects destruction identities before removing
rows. Later systems in the same complete tick observe those changes.

### Systems

``System`` implementations receive mutable access to ``World`` for one step.
Systems that process components iterate or join stores directly instead of
routing hot-path work through entity facades. Existing rows are mutated with
``ComponentStore/update(for:_:)``.

The production Engine foundation is limited to camera input, acceleration
intent, movement, rotation, and input cleanup. The current mining behavior
supplies collision baselines, rail motion, forces, collision resolution,
interaction, and camera follow at Game Content stages. Game Content can compose
these systems only through ``SimulationBehavior`` and
``SimulationSystemSchedule``; it cannot replace or reorder the Engine-owned
foundation.

Authoritative translational positions, velocities, accelerations, impulses,
and fixed-step seconds use `Double`. ``SimulationPresentationSnapshot`` narrows
entity positions to `Float`; camera, Render, and GPU values use single precision.

### Semantic Input and Selection

``InputRuntime`` publishes context-free translation and interaction intent plus
cumulative camera and selection values. At a fixed-step boundary, Simulation
derives interval-local changes and interprets them using authoritative ECS
state. Selection updates selection rows, and control routing applies held
translation or interaction only to the selected player-controlled entity.
Selecting a non-controllable entity or clearing selection clears the previous
control row. The Input Runtime never receives an entity identity.

The SwiftUI orbit-assist action uses a separate directed command boundary.
``SelectedEntityInspector`` passes the displayed entity's complete ``EntityID``
through a focused callback, and ``RealtimeAssemblyViewModel`` routes it to
``RealtimeAdvanceDriver``. The driver generation-tags the pending command and
captures ``OrbitCircularizationCommand`` in the next cursor-qualified request.
After cursor validation, ``SimulationRuntime`` imports the command only for the
request's first tick, where it may engage persistent per-entity autopilot state.
Neither the command nor that state enters ``InputSnapshot`` or ``InputState``.

### Mining Slice Dynamics

The mining slice composes rail-driven and dynamically integrated motion in one
schedule. The star supplies gravity. The skiff integrates gravity, propulsion,
fuel use, cargo-dependent live mass, collision response, and request-engaged
orbit assistance. ``MassComponent`` derives live mass from dry mass plus the
current fuel and cargo rows; ``LiveMass`` exposes the same projection through a
facade.

The selected skiff can fire a missile with M. A cumulative semantic fire press
becomes a one-tick control request. ``MissileLaunchSystem`` constructs a visible,
dynamically integrated missile aimed at the nearest destructible asteroid,
leading its current velocity. ``MissileImpactSystem`` tests relative swept
motion, removes missiles on solid impacts, and destroys targets carrying
``DestructibleComponent``. Missiles expire after their configured lifetime.
The skiff retains its existing held Space action for mining and depot service.

Six asteroids and one depot initially follow deterministic circular rails. During
`worldPreparation`, ``PreviousPositionCaptureSystem`` records collision sweep
baselines and ``OrbitalRailSystem`` updates rail positions and velocities.
``OrbitCircularizationSystem`` consumes the one-shot command during
`inputConsumption`. In `forceContribution`, gravity runs before
``OrbitCircularizationAutopilotSystem``, which runs before manual
``FlightControlSystem``. While engaged, the autopilot suppresses manual
translation and limits each contribution by thrust, fuel, live mass, and fixed
step duration.

A rail is a complete motion policy, not a force contribution. A body must not
receive rail placement and dynamic integration in the same tick. A future
perturbation feature needs an explicit transition from rail state to dynamic
position and velocity.

### Presentation and Rendering

A concrete `RenderRuntime` type remains proposed, but the current screen path
already preserves the Runtime boundary:

1. Systems update ``World``.
2. ``SimulationRuntime`` publishes a completed
   ``SimulationPresentationSnapshot``.
3. ``RenderFrame`` projects that snapshot into private Render state.
4. ``MetalRenderer`` delegates private resource preparation and encoding to
   ``MetalFrameEncoder``, then submits and presents the frame.

``World`` contains backend-neutral mesh and material identities plus the
authoritative camera. It does not own Metal objects, decoded models, or Render
caches.

### Entity Facades

``Entity`` subclasses such as ``Ball`` are typed, ergonomic views over live ECS
state for Game Content, UI, and tooling. They are not a second authoritative
state model.

The selected-entity inspector receives a narrow Simulation-owned source that
resolves the selected complete ``EntityID`` to its registered facade. It renders
the capability protocols that facade supports. The read source remains separate
from the orbit-assist callback: the view can submit an identity but cannot
mutate the facade or ``World``. Gameplay inspection fields therefore do not
expand ``SimulationPresentationSnapshot``.

## Fixed-Step Simulation

The portable Simulation primitive is an exact Runtime-level request:

1. A caller supplies an optional expected ``SimulationCursor``, a positive
   ``SimulationStepCount``, one immutable ``SimulationInputAssignment``, and an
   optional orbit command.
2. ``SimulationRuntime`` validates the expected cursor inside its serialized
   mutation domain.
3. The Runtime applies a rebase without replaying prior cumulative transients,
   or assigns an ingest snapshot to the first requested step. A
   `rebaseThenIngest` assignment performs both operations in the same accepted
   request.
4. ``Engine`` executes the complete ordered schedule exactly as many times as
   requested.
5. ``SimulationRuntime`` publishes the final completed presentation and returns
   the initial cursor, final cursor, completed count, and exact final snapshot.

``SimulationRuntime/fixedTimeStep`` is the sole production definition of one
tick and currently equals 1/60 second. Assembly policy may decide when to ask
for work, but it cannot substitute another tick duration. Assemblies advance
through ``SimulationAdvanceTarget``; direct ``Engine`` stepping remains a
Runtime implementation detail and a focused integration-test seam.

Drawing has an independent cadence. A draw may reuse the last completed
snapshot, and several ticks may complete before the next draw.

## Current Limits

- ``EntityID`` reservation remains monotonic with generation zero. Destruction
  and component removal compact dense storage; generation incrementing and index
  reuse remain unimplemented.
- Calling ``World/add(_:from:)`` again with the same live facade reseeds its
  rows. Registering a different facade for that identity fails a precondition;
  destroyed facades cannot be registered again.
- ``World`` has a fixed store list and a fixed capability-to-seed translation.
  External consumer-defined component storage is not supported.
- Systems execute one flat ordered list with controlled Game Content insertion
  stages. Dependency-derived ordering and safe parallel execution remain
  proposed.
- ``SimulationPresentationSnapshot`` is the only general completed Simulation
  publication. The selected-entity source is a narrow in-process live view;
  retained publication history and replay storage are not implemented.

## Topics

### Core Symbols

- ``Engine``
- ``SimulationConfiguration``
- ``SimulationBehavior``
- ``SimulationSystemSchedule``
- ``World``
- ``System``
- ``Entity``
- ``ComponentStore``

### Related Architecture

- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
