# Celestial Dynamics and Navigation

Engine2 makes gravity predictable gameplay state. Given the same authoritative
state and maneuver plan, the trajectory shown to the player must match the
trajectory Simulation executes until an identified event invalidates that
prediction.

## Status

Partially implemented.

The first slice projects one validated ``GeneratedStarSystem`` into a versioned
planar rail system. It gives each resolved planet and moon deterministic orbital
orientation and phase at a shared epoch, evaluates the hierarchy through one
Kepler propagation kernel, evaluates the summed Newtonian field at a requested
point, produces circular-reference Hohmann transfer plans, and presents those
results in the native star-system explorer. The explorer adds bounded viewport
zoom, display-only epoch playback at selectable rates, and a symbolic reference
vehicle without creating authoritative spacecraft state or Simulation authority.

This slice is construction and inspection tooling. It does not create
authoritative Simulation state, propagate ships, consume propellant, execute a
maneuver, or prove that the generated architecture remains stable under mutual
gravity. The current `coreAccretionLiteV1` generation model still uses analytic
Hill, radial-clearance, Roche, and satellite-region admission. Those filters are
not a numerical N-body stability proof.

## Gameplay Promise

Gravity defines the game's geography and transportation economy. A player must
be able to inspect a route before committing material, time, or propellant and
then receive the predicted result when no new event changes the initial state.

A complete navigation result should eventually report:

- departure epoch and flight time
- each burn's direction, duration, and delta-v
- propellant consumed and protected reserve
- target position at arrival
- arrival-relative velocity and capture or braking cost
- closest approach or encounter periapsis
- a terminal result such as rendezvous, capture, flyby, impact, fuel exhaustion,
  or escape

Reaching a target's position is not the same as stopping there. A transfer that
intersects a planet with substantial relative velocity is a flyby or impact
unless the plan also provides a capture or rendezvous maneuver.

## Ownership and Boundaries

Star-system generation and gravity-system generation are finite Game Content
construction operations. They own no Runtime lifecycle, cadence, task, ECS
state, or Render state.

The implemented ownership is:

- ``StarSystemGenerator`` resolves immutable stellar, planetary, satellite,
  composition, environment, and reduced-orbit facts.
- ``GravitySystemGenerator`` projects those validated facts into one immutable,
  versioned planar rail hierarchy.
- ``PlanarKeplerPropagationKernel`` evaluates one rail without owning time or
  mutable body state.
- ``GravitySystemEphemeris`` evaluates the generated hierarchy at a requested
  epoch.
- ``PlanarGravityField`` evaluates star, planet, and moon acceleration without
  integrating a moving body.
- ``HohmannTransferPlanner`` derives a circular two-impulse reference plan from
  immutable orbit and primary facts.
- `StarSystemExplorer` owns the native inspection UI. It does not become the
  authority for generation, propagation, or maneuver execution.

The future authoritative path belongs inside ``SimulationRuntime``. Simulation
will own celestial time, dynamic body state, maneuver acceptance and execution,
collision facts, and completed navigation publications. A predictor may run the
shared propagation implementation against an immutable Simulation-owned value,
but only Simulation may commit the result to ``World``.

Navigation state should use a purpose-specific Simulation-owned Snapshot. It
should not turn ``SimulationPresentationSnapshot`` into an exhaustive copy of
World. The App-owned Runtime Assembly will connect that publication to planning
and presentation tools through explicit typed boundaries.

## Implemented Planar Rail Model

The implemented rail model constrains center-of-mass motion to one system plane.
The Render projection may remain fully three-dimensional: planets can be
spheres, axial tilt and spin may be three-dimensional, and terrain, rings,
effects, ships, and cameras may extend outside the plane. Those presentation
choices do not change the authoritative orbital plane.

The model uses `Double` physical values rather than the current `Float`
presentation transforms. Its domain separates:

- ``CelestialEpoch``
- ``PlanarPosition``
- ``PlanarVelocity``
- ``PlanarStateVector``
- ``PlanarAcceleration``
- ``PlanarTrajectorySample``
- ``GravitationalParameter``
- ``PlanarKeplerianRail``
- ``CelestialDynamicsModelVersion``

A planar rail retains semimajor axis and eccentricity plus the information that
the reduced V1 orbit omits:

- longitude of periapsis in the system plane
- mean anomaly at its reference epoch
- the reference epoch

``GravitySystemGenerator`` derives orientation and phase deterministically. It
does not mutate the persisted V1 generated system or reinterpret V1 inclination
as player freedom outside the plane. A gravity-model change that alters phase,
orientation, hierarchy, propagation, or transfer output requires a new
``CelestialDynamicsModelVersion`` rather than a silent change to an existing
version.

## Shared Kepler Propagation

``PlanarKeplerPropagationKernel`` advances a bound elliptical rail to an
absolute ``CelestialEpoch`` and returns its parent-relative
``PlanarStateVector``. One implementation owns anomaly solving and conversion
into planar position and velocity.

``GravitySystemEphemeris`` uses that kernel hierarchically:

1. The star defines the root frame.
2. Each planet evaluates relative to the star.
3. Each moon evaluates relative to its parent planet.
4. The ephemeris adds parent state to child state to produce system-plane state.

This is a deterministic hierarchical ephemeris, not coupled N-body evolution.
Rail bodies do not exchange momentum or perturb one another. Analytic rail
evaluation therefore remains bounded and drift-free over ordinary inspection
while leaving major perturbations and mutual gravity for a later model.

## Implemented Gravity Field

``PlanarGravityField`` sums inverse-square Newtonian acceleration from the star
and every generated rail body at one position and epoch. It evaluates moving
sources through ``GravitySystemEphemeris`` in stable body-identity order and may
exclude one generated identity from its own query.

The field uses each source's resolved mass and physical radius. A query at or
inside a source radius returns typed contact instead of applying arbitrary
softening or dividing by a singular distance. A nonfinite sum also fails rather
than becoming trajectory input.

The field is not a trajectory propagator. It owns no craft state, integration
step, collision outcome, or Simulation authority. Restricted N-body ship
propagation remains proposed.

## Circular-Reference Hohmann Plans

``HohmannTransferPlanner`` provides the first navigation calculation. It treats
the departure and destination semimajor axes as circular, coplanar orbits around
the generated star. It derives the next prograde opportunity at or after a
requested epoch, the wait and transfer durations, both ideal impulses, the
required reference phase, and a sampleable transfer rail.

That result is useful for explaining an economical transfer and comparing the
scale of routes. It is not an executable transfer for arbitrary generated
orbits. In particular, the first planner does not solve:

- departure from an eccentric body's instantaneous state
- arrival at an eccentric moving target
- a transfer involving a moon or another primary
- a fixed-time intercept
- velocity-matched rendezvous under multiple gravity sources
- finite thrust or changing vehicle mass
- collision, capture, or escape events

A future planner may use Hohmann or Lambert solutions as candidates. Any path
shown as executable must be propagated and classified through the same force,
thrust, and event model that Simulation will execute.

## Native Dynamics Explorer

The existing `StarSystemExplorer` target contains separate Generation and
Dynamics workspaces. Generation continues to present formation, environment,
classification, and conservation facts. Dynamics projects the same generated
system into its versioned planar hierarchy, exposes epoch-dependent orbital
state, reports the summed field at the selected departure planet while excluding
that planet's self-gravity, and presents circular-reference transfer information.

The Dynamics workspace is a calibration and design tool. Its diagram is a
projection of ``GravitySystemEphemeris`` output; SwiftUI does not reproduce the
Kepler equations. Its transfer presentation projects
``HohmannTransferPlan`` rather than inventing UI-only delta-v values.

The diagram applies centered zoom from 0.25× through 8× using
`GravitySystemViewport`. Zoom changes only the mapping from physical planar
meters to canvas points. It does not change ephemeris state, gravity, or the
sampled transfer rail.

`GravitySystemPlayback` maps absolute `TimelineView` dates onto the bounded
displayed epoch. The controls can pause playback or select one displayed day,
30 displayed days, one displayed year, or ten displayed years per wall-clock
second. Manual scrubbing reanchors active playback, and playback stops at the
current epoch bound. This display clock calls the existing explorer epoch API;
it owns no propagation or Simulation cadence.

At each displayed epoch, `GravityTransferVehicleProjection` places one symbolic
vehicle on the circular-reference transfer. It remains at the departure endpoint
before departure, uses ``PlanarKeplerPropagationKernel`` during the reference
flight, and remains at the arrival endpoint afterward. The marker is not an
executed spacecraft, an authoritative prediction, or evidence of rendezvous
with the potentially eccentric generated destination rail.

Future explorer work should add authoritative predicted and executed paths,
burn and coast segments, target ghosts at arrival, relative-velocity vectors,
fuel state, encounter markers, and stability-audit results only after the
corresponding production model exists.

## Determinism and Persistence

The gravity projection has a deterministic address independent of wall time,
render cadence, Swift hashing, or collection iteration order. Stable source-body
identity and the gravity-model version determine body-specific phase and
orientation. Hierarchy and gravity-field evaluation use stored stable body
order.

``GeneratedGravitySystem`` is `Codable`, but decoding does not establish trust.
A persistence boundary must call ``GeneratedGravitySystem/validate()`` before
constructing an ephemeris, gravity field, or transfer planner.
Validation checks model admission, finite star and body facts, stable identity
order, hierarchy, periapsis clearance from each primary, canonical angles,
common epoch, exact seed-derived phase, and rederived two-body gravitational
parameters. It does not authenticate bytes, replay star-system formation, or
rederive retained source mass, radius, semimajor axis, or eccentricity.

Persisted gameplay state will need more than the original generation seed. A
future save should retain:

- the complete resolved generated system
- the celestial-dynamics model version
- the authoritative celestial epoch and dynamic state
- accepted maneuver and perturbation events
- periodic dynamic checkpoints when replay cost or chaotic divergence requires
  them

The current floating-point contract should match star-system generation:
reproduce exact output on the pinned supported toolchain and architecture, and
persist resolved state rather than promising seed-only bit identity forever.

## Generated-System Admission

Rails make a quiet generated system inexpensive and visually stable. They do
not establish that the same architecture will remain stable after promotion to
mutual gravity.

A future gravity-ready generation version should require:

- complete phase-qualified planar state for every gravitationally significant
  body
- no gravitationally significant survivor hidden only inside an orbitless
  aggregate
- analytic spacing and collision admission
- deterministic numerical qualification with the production massive-body force
  model
- a declared qualification horizon and explicit tolerances
- failure on an unintended collision, ejection, orbit crossing, stellar impact,
  or moon escape
- bounded energy, angular-momentum, and orbital-element error attributable to
  the numerical method

The qualification horizon is finite. Engine2 should not claim that a chaotic
many-body system is stable forever. Ordinary unit tests should cover exact
invariants and reference systems; longer ensemble audits should measure
generated populations and rare instability outside the normal test suite.

## Proposed Ship Propagation and Propulsion

Ordinary ships should begin as gravitational test bodies. They feel the summed
gravity of relevant stars, planets, moons, and resolved minor bodies without
perturbing those sources. This restricted N-body path should evaluate rail
sources at absolute epochs and numerically propagate the ship between ordered
events.

Vehicle capability should derive from physical state:

- dry mass
- payload mass
- propellant mass
- exhaust velocity or specific impulse
- maximum thrust and mass-flow rate
- throttle, engine availability, and protected reserve

Available delta-v follows from those facts. Thrust divided by current wet mass
controls acceleration and burn duration. A cargo-heavy freighter may have the
range for a route without enough thrust for a short capture burn; a warship may
reduce travel time only by spending the propellant needed to slow down.

Impulsive burns remain useful planning references. Authoritative finite burns
must apply gravity, thrust, and propellant loss continuously through the shared
propagation model.

## Prediction and Execution Contract

An executable prediction must retain:

- its source Simulation cursor and celestial epoch
- stable craft and target identities
- a maneuver-plan identity and revision
- the celestial-dynamics, propulsion, and collision model versions
- the exact initial state and solver policy required for replay

Prediction and execution must share rail evaluation, gravity accumulation,
propagation steps, thrust, fuel cutoff, event detection, and terminal
classification. The rendered trajectory is a sampling of that result, not an
independent approximation.

An accepted impulse, changed maneuver, collision, new gravity source, or other
authoritative intervention invalidates affected predictions. The UI should show
the stale reason and recompute from a new immutable source value. It must not
silently bend an old path into a different executed route.

Time acceleration must preserve the same contract. Rails may evaluate directly
at an absolute epoch, and certified coast segments may skip uneventful display
samples. Active burns and close encounters require bounded propagation and
event searches. Time warp must stop before burns, impacts, encounters, or fuel
exhaustion instead of enlarging one step until an event is skipped.

The current 1/60-second exact Simulation tick does not by itself make months of
interplanetary travel practical. Runtime integration needs an explicit
Simulation-owned celestial-time and event-advancement design. An assembly or
renderer must not redefine physics time as presentation policy.

## Proposed Massive-Body Promotion

A planet-scale projectile or other meaningful gravitational intervention should
promote the coupled massive hierarchy at an exact Simulation boundary:

1. Evaluate every affected rail at the transition epoch.
2. Convert the hierarchical states into one momentum-consistent dynamic state.
3. Apply the accepted spawn, impulse, or collision event.
4. Advance all promoted massive bodies through one versioned N-body policy.
5. Invalidate predictions that depended on the former rails.

The first promotion model should remain dynamic. Automatic re-railing requires
orbit fitting, hierarchy selection, resonance handling, qualification, and
continuity rules and remains proposed.

Gravity determines contact, capture, exchange, and ejection. Detailed impact
outcomes such as fragmentation, atmosphere stripping, heating, debris, and
remnant formation belong to a separate versioned collision model.

## Proposed Belts and Comets

The generator should distinguish resolved bodies from statistical populations:

- A belt retains its mass, radial extent, composition, and population
  distribution without creating an ECS entity for every member.
- Selected large asteroids can receive resolved rails and source gravity when
  their mass justifies it.
- Display tracers represent a population and must not double-count its mass.
- Active comets can become resolved test bodies drawn deterministically from an
  outer reservoir.

A belt is expected to occupy a persistent admissible region. An active comet
may correctly impact a body, become temporarily captured, or escape. Permanent
stability is therefore not one universal requirement for every generated
object.

## Verification

Focused tests currently pin:

- exact same-source gravity-system equality and stable body order
- pinned V1 phase and orientation values
- complete projected body count and selected retained planet and moon orbit facts
- parent-plus-child hierarchical position and velocity composition
- stellar and parent-body periapsis-contact rejection
- circular closure, quarter-orbit states, eccentric apsides, and sampling endpoints
- self-excluded starward acceleration for a circular reference body
- Earth-to-Mars window, transfer duration, phase, impulses, and kernel endpoints
- explorer projection, stable transfer selection, symbolic reference-vehicle
  endpoints and in-flight propagation, zero- and one-planet states, bounded
  viewport mapping, and deterministic display playback and reanchoring

Additional first-slice coverage should exercise hostile decoded values, phase
corruption, inward transfers, planner refusals, gravity contact refusal, and
rendered SwiftUI control interaction.

Future authoritative work additionally requires predictor-executor agreement,
planarity, stable force accumulation, fuel exhaustion, collision and escape
event detection, time-warp equivalence, massive-body conservation, and
generated-system stability ensembles.

## Non-Goals of the First Slice

The first slice does not provide:

- authoritative ECS or Runtime integration
- restricted or coupled N-body propagation
- ship, station, asteroid, or comet dynamics
- propulsion, finite burns, fuel use, capture, or rendezvous
- automatic stability certification
- arbitrary three-dimensional center-of-mass motion
- general relativity, tides, oblateness, atmospheric drag, or impact
  hydrodynamics
- automatic route optimization or hidden rerolls for gameplay value

## Related Architecture

- <doc:Star-System-Generation>
- <doc:Star-System-Generation-Calibration>
- <doc:Game-Content-Architecture>
- <doc:Engine-Architecture>
- <doc:System-Scheduling>
- <doc:Runtime-Architecture>
- <doc:Runtime-Communication>
- <doc:Rendering-Architecture>
