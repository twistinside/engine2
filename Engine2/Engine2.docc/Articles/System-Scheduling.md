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

These stages are controlled extension points, not a replacement scheduler. Game
Content cannot remove the foundation or move a system across a stage boundary
after construction. The Engine foundation contains no history stage.
``PreviousPositionCaptureSystem`` is a collision-sweep baseline supplied by the
mining behavior at `worldPreparation`.

``MiningSimulationBehavior`` contributes this exact order:

| Stage | Systems in declaration order |
| --- | --- |
| `inputConsumption` | ``PlanarSelectionSystem``, ``SelectedEntityControlSystem``, ``OrbitCircularizationSystem`` |
| `worldPreparation` | ``PreviousPositionCaptureSystem``, ``OrbitalRailSystem`` |
| `forceContribution` | ``GravitySystem``, ``OrbitCircularizationAutopilotSystem``, ``FlightControlSystem`` |
| `postMovement` | ``SweptCollisionSystem``, ``MiningInteractionSystem``, ``CameraFollowSystem`` |
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
source, and only the skiff is dynamically integrated. The six asteroids and
depot use analytic rails. Mining's camera policy orbits about the Z normal of
the XY gameplay plane, and flight control normalizes the camera's projected
planar axes before interpreting translation.

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
