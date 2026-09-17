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
acceleration-intent, movement, rotation, input-cleanup, and entity-removal systems.
It inserts the behavior's ``SimulationSystemSchedule`` systems only at the named
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

Each concrete entity has a designated initializer for its authored spawn
values. It assembles one flat `Entity.InitialState` from scalar and SIMD
values, enums, and typed identities, then calls `super.init(in:from:)`.
Initial state contains no intermediate seed structures or component instances.
The base Entity initializer reserves the identity and calls
``World/add(_:from:)``, which validates the facts against advertised
capabilities, constructs the components, and performs every construction-time
store write. Every specialized capability requires all of its authored fields;
a renderable entity, for example, must supply both mesh and material identities.

The World derives capability markers and neutral player control from the
facade's conformances. Every collision body receives a previous position equal
to its resolved spawn position. Depot delivery totals start at zero, and an
expirable entity's remaining lifetime starts from its authored duration.
Ownership and lifetime remain separate authored values.

An ``Orbiting`` entity supplies its complete rail placement through four fields:

```swift
let initialState = Entity.InitialState(
    orbitalPrimaryID: star.id,
    orbitalRadius: 1_800,
    orbitalAngularSpeed: 0.001,
    orbitalPhase: 0.35
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

The base ``Entity`` owns its identity. ``DestructibleComponent`` stores the
authoritative ``DestructibleComponent/State``: `active` or `pendingRemoval`. World creates
an active lifecycle row on first registration and preserves that state when
reseeding component values. Systems request final collection by setting the row
to `pendingRemoval`.

The base Entity declares ``Destructible`` conformance and inherits its default
read-only ``Destructible/lifecycleState`` projection. It returns the component state only when
that facade is the registered instance for its complete identity; an unregistered,
removed, or alias facade reports `nil`. Systems update the lifecycle component
directly. Marking preserves the registered facade and its component rows, so later
systems can inspect them before final collection.

Gameplay systems iterate or join component stores and consult lifecycle rows
when deciding whether a participant is active. Bounce, mining
interactions, and camera follow exclude nonactive entities.

The Engine's final ``EntityRemovalSystem`` snapshots pending identities from the
lifecycle store after `prePresentation` and input cleanup. It calls
``World/destroy(_:)`` in deterministic identity order. World teardown removes
the facade from the registry and removes all its component rows. It also clears
selection, camera follow, and any pending orbit command targeting that identity.
The retained facade then reports `nil` for lifecycle state. Unknown or stale
identities leave the World unchanged. ``ComponentStore/remove(for:)`` compacts
dense storage and repairs the moved row's sparse lookup. Final collection also
clears the current tick's collision data.

Existing presentation snapshots remain unchanged; the next completed snapshot
omits removed entities. First registration requires an outstanding World
reservation, so a destroyed facade cannot register again.

Systems collect structural work before applying it. A launch system constructs
typed entities through ``World/add(_:from:)`` after collecting its launch
requests. Impact and expiry systems mark entities during gameplay; only the
final removal system compacts their stores during the production schedule.

### Systems

``System`` implementations receive mutable access to ``World`` for one step.
Systems that process components iterate or join stores directly, including
lifecycle rows when needed.
Existing component rows are mutated with ``ComponentStore/update(for:_:)``.

The production Engine foundation supplies camera input, acceleration intent,
movement, rotation, input cleanup, and final entity removal. The current mining
behavior supplies collision baselines, rail motion, forces, collision detection
and response, expiry marking, interaction, and camera follow at Game Content stages. Game Content can compose
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
dynamically integrated missile aimed at the nearest active solid body with an
ore-deposit component, including a depleted deposit, leading its current velocity.
This choice belongs to Mining Game Content;
neither health nor removal capability makes an entity a target.
``Missile`` composes ``ContactDamaging``, ``ContactConsumable``, ``Ownable``,
and ``Expirable`` with movement, collision, scale, and rendering. Its collision
response is a sensor with explicit owner exclusion and solid-body contact scope. It supplies one point of
damage and consumes itself on the first eligible contact. Ownership and lifetime
remain separate component rows.

``Destructible`` is a standalone protocol exposing read-only lifecycle state
without requiring Entity inheritance. The base ``Entity`` declares conformance,
so every subclass inherits that view of its ``DestructibleComponent``.
Systems request deferred removal through the component store.

``Damageable`` exposes health stored in ``HealthComponent``. ``HitPoints`` keeps
health and damage finite and nonnegative; initial health and outgoing contact
damage must be positive. Asteroids start with one health point. The skiff, depot,
and star have no health rows, so contact damage does not remove them. Their
universal removal capability remains available for other lifecycle decisions.

``CollisionSystem`` joins collision and position rows for active entities and
captures contacts before applying gameplay policy. Each ``CollisionContact``
contains a canonical pair of complete entity identities, its contact fraction
of the tick, and a normal directed from the second entity toward the first.
``World/collisionContacts`` retains those original facts for the tick.
``World/collisionSweeps`` retains each active body's ``CollisionSweep``:
original start and end positions, radius, and start-of-tick lifetime fraction.

``ContactEffectSystem`` selects the first eligible contact for each source with
contact damage or contact consumption. ``CollisionContactFilter`` requires active
participants, acceptance by the source's ``CollisionContactScope``, and both
participants' owner-contact policies. Ownership attribution alone does not imply
exclusion. Sensors do not obstruct solid bodies, but may receive damage when a
source accepts all bodies. The missile explicitly restricts its effects to solids.

The system captures every source's choice before writing effects, applies damage
only to health-bearing recipients, then marks consumed sources and exhausted
recipients for final removal. A persistent damaging body and a harmless consumable
probe can reuse these capabilities independently. A persistent source applies its
damage once per tick while an eligible contact remains.

``LifetimeSystem`` independently advances lifetime rows and marks expired
entities. Detection runs first and clips both paths to the time
both bodies still exist, preserving contacts during the final partial interval
before expiry.

``CollisionResponseSystem`` applies bounce policy to active solid bodies
in dynamic component-store order. An earlier positional response can change a
later collision. The response re-evaluates affected pairs through the same
``CollisionEvaluator`` used by detection, retaining the captured lifetime
baseline. It refreshes its own working data and preserves the World's original
contacts for other consumers.

Component rows, registered facades, and collision data remain available until
the Engine's final collection. Explosion propagation and collision-force
contributions remain future direction. The skiff retains its
existing held Space action for mining and depot service.

Six asteroids and one depot initially follow deterministic circular rails. During
`worldPreparation`, ``PreviousPositionCaptureSystem`` records collision sweep
baselines and ``OrbitalRailSystem`` updates rail positions and velocities.
If a rail's primary is removed, the rail retains its last position and velocity;
it does not switch to dynamic integration or remove its orbiting entity.
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

``Entity`` owns identity and projects lifecycle state. Subclasses such as ``Ball`` provide
typed, ergonomic views over live component values for Game Content, UI, and
tooling. Gameplay values remain authoritative in their component stores.

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
- ``DestructibleComponent``
- ``DestructibleComponent/State``
- ``ComponentStore``

### Related Architecture

- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>
- <doc:Runtime-Communication>
- <doc:Game-Content-Architecture>
