# System Scheduling

Engine2 currently executes one complete ordered system list for each fixed
Simulation tick. This article documents that implemented order and separates it
from the proposed dependency, cadence, and background-work model.

## Status

The named ``SimulationSystemSchedule`` stages are implemented. Dependency
metadata, derived parallel stages, per-system cadence, and background result
application remain proposed.

ECS systems and their schedule live inside the authoritative Simulation
Runtime. A ``System`` is scheduled simulation logic, not a top-level Runtime.
An assembly-owned advance driver decides when to request progress, while
``SimulationRuntime`` and ``Engine`` define and execute one complete tick. See
<doc:Runtime-Architecture> and <doc:Runtime-Assemblies-and-Advancement>.

Platform event collection and physical mapping are outside the ECS schedule.
`MetalScenePlatformView` submits ``InputEvent`` values through
``InputEventSink``, and ``InputRuntime`` publishes the latest immutable
``InputSnapshot``. For an accepted request, ``SimulationRuntime`` applies any
input rebase and passes an ingest snapshot only to the first
``Engine/step(inputSnapshot:)`` call. In the mining behavior, scheduled systems
then derive interval camera and selection values, resolve selection, route held
control intent, apply camera input, and clear interval-local input.

The SwiftUI orbit-assist action also remains outside the Input publication
path. ``SimulationRuntime`` imports its request-carried
``OrbitCircularizationCommand`` only for the first tick of the exact batch.
That command may engage Simulation-owned autopilot state, which later ticks
advance without replaying the request.

## Implemented Behavior Stages

``SimulationBehavior`` creates a fresh ``SimulationSystemSchedule`` for one
Engine construction. The Engine flattens its systems into this fixed order:

1. Game Content `inputConsumption`
2. Engine-owned camera input
3. Game Content `worldPreparation`
4. Game Content `forceContribution`
5. Engine-owned acceleration intent, movement, and rotation
6. Game Content `postMovement`
7. Game Content `prePresentation`
8. Engine-owned input cleanup
9. Engine-owned removal collection

These stages are controlled extension points, not a replacement scheduler. Game
Content cannot remove the foundation or move a system across a stage boundary
after construction. The Engine foundation contains no history stage.
``PreviousPositionCaptureSystem`` is a collision-sweep baseline supplied by the
mining behavior at `worldPreparation`.

``MiningSimulationBehavior`` contributes this exact order:

| Stage | Systems in declaration order |
| --- | --- |
| `inputConsumption` | ``PlanarSelectionSystem``, ``SelectedEntityControlSystem``, ``OrbitCircularizationSystem`` |
| `worldPreparation` | ``MissileLaunchSystem``, ``PreviousPositionCaptureSystem``, ``OrbitalRailSystem`` |
| `forceContribution` | ``GravitySystem``, ``OrbitCircularizationAutopilotSystem``, ``FlightControlSystem`` |
| `postMovement` | ``CollisionSystem``, ``FireableImpactSystem``, ``LifetimeSystem``, ``CollisionResponseSystem``, ``MiningInteractionSystem``, ``CameraFollowSystem`` |
| `prePresentation` | None |

The circularization system consumes and clears the one-shot command before
camera input and movement. It validates the complete target identity and
current maneuver state before engaging per-entity autopilot state. While
engaged, the autopilot suppresses manual translation and contributes only the
acceleration and fuel use supported by maximum thrust, current fuel, live mass,
and fixed-step duration. Movement integrates gravity and the autopilot
contribution together instead of replacing velocity atomically.

``MiningInteractionSystem`` joins the shared ``InteractionComponent`` range
with mining- or depot-specific component rows. The star is the sole gravity
source. The skiff and its missiles are dynamically integrated; surviving
asteroids and the depot use analytic rails. Mining's camera policy orbits about the Z normal of
the XY gameplay plane, and flight control normalizes the camera's projected
planar axes before interpreting translation.

``MissileLaunchSystem`` consumes each selected launcher's fire request and
constructs missiles before collision baselines are captured. Missiles therefore
move and participate in swept impact checks on their first tick.
``CollisionSystem`` captures geometric contacts between active collision bodies
before gameplay response policies run. It stores immutable ``CollisionContact``
values in ``World/collisionContacts`` and each body's original swept path in
``World/collisionSweeps``. Contacts identify a canonical entity pair, a fraction
of the complete tick, and a normal directed from the second entity toward the
first. Detection includes owners and fired-body pairs; the response policy
decides which contacts matter.

``FireableImpactSystem`` selects the earliest eligible captured contact for each
fired body, excluding its owner and other fired bodies. It marks both
participants through ``Destructible/markForRemoval()``, which transitions the base
Entity's authoritative lifecycle from `active` to `pendingRemoval`. Repeated
requests on the registered pending facade succeed without another transition.
Ownership and lifetime remain independent component rows. Every Entity conforms
to the standalone Destructible protocol; destructibility has no component row.

``LifetimeSystem`` advances lifetime rows and marks expired entities, including
entities without collision or fired-body capabilities. Detection runs before
expiry and captures each body's start-of-tick lifetime fraction in its
``CollisionSweep``. Both paths are clipped to the shorter remaining lifetime.
Contacts compare elapsed tick time, so different expiry times cannot change
which eligible contact occurs first.

``CollisionResponseSystem`` applies bounce policy to active bodies and excludes
fired bodies. It preserves dynamic component-store order. When an earlier
positional response invalidates a later pair, it re-evaluates that pair through
the shared ``CollisionEvaluator``, using the captured lifetime baseline. These
updates affect the response's working data; the World's original contacts remain
unchanged for other consumers. Mining interactions and camera follow also
exclude nonactive entities.

Pending entities retain their component rows and registered facades through
`prePresentation`. After all Game Content systems and input cleanup,
``EntityRemovalSystem`` scans a registry snapshot and removes pending entities
through ``World/destroy(_:)``. Teardown transitions each
facade to `removed`. Final collection clears both collision buffers. The Engine
completes the tick only after this collection, so the next completed presentation
omits removed entities.

This separation leaves room for future explosion propagation, collision-force
contributions, and health-based damage decisions before final collection.
Those responses remain proposed; current impact policy marks both contact
participants for deferred removal.

A future perturbation feature needs an explicit rail-to-dynamics transition. A
body must not receive rail placement and dynamic integration in the same tick.

## Non-Reentrant Updates

``SimulationRuntime`` serializes accepted advances, and
``RealtimeAdvanceDriver`` waits for each exact result before issuing another
request on its connection. Additional elapsed time becomes accumulator debt for
a later bounded request; it does not authorize an overlapping world update.
Future worker execution must preserve this single-writer boundary.

## Proposed Dependency Graph

A future scheduler may derive an execution graph from metadata that declares:

- components and resources read by each system
- components and resources written by each system
- explicit before-and-after constraints
- a coarse semantic phase when data conflicts alone cannot choose direction

Read/write metadata identifies conflicts, but it does not always determine
which system should run first. Phase rules or explicit constraints must supply
that semantic order. The resulting directed graph should reject cycles instead
of selecting an arbitrary order.

The graph can then form execution stages. Systems within one stage have no
unmet dependencies and may run in parallel. A barrier separates each stage
from the next. These dependency-derived stages would be an internal scheduling
mechanism, distinct from the implemented Game Content insertion stages.

Possible coarse phases include input interpretation, gameplay and force
contribution, integration, resolution, cleanup, and presentation export. Only
export belongs inside the Simulation schedule. Rendering and Metal submission
consume completed presentation state at Render cadence.

The current real-time schedule has no presentation-owned viewpoint controller.
``CameraInputSystem`` mutates the authoritative camera during a complete tick,
and the screen observes that camera only through a completed snapshot. Future
gameplay-authoritative camera rigs or sensors belong at the same Simulation
authority boundary.

## Proposed Per-System Cadence

Work such as AI planning, inference, or expensive perception may not need to
run every tick. A future scheduler can represent cadence as every tick, every
fixed number of ticks, a simulation-time interval, or an explicit demand.
Cadence must derive from Simulation time rather than render frames so fixed-step
execution remains deterministic.

## Proposed Background Work

Background work must not mutate ``World`` directly. A future integration should:

1. Capture the required state in an immutable work payload.
2. Run the expensive operation outside the Simulation mutation domain.
3. Apply a validated result during a later scheduled tick.

This keeps authoritative mutation inside the scheduler while allowing expensive
computation elsewhere.

## Topics

### Architecture

- <doc:Runtime-Architecture>
- <doc:Runtime-Assemblies-and-Advancement>

### Related Symbols

- ``Engine``
- ``World``
- ``System``
- ``SimulationBehavior``
- ``SimulationSystemSchedule``
- ``CameraInputSystem``
- ``MovementSystem``
