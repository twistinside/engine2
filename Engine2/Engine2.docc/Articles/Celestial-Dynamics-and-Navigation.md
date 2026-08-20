# Celestial Dynamics

Engine2 stores celestial motion as authoritative Simulation state and advances
it through one versioned planar mechanics stack.

## Status

Partially implemented.

The implemented work connects generated Game Content to authoritative ECS
state. ``GravitySystemGenerator`` projects one validated
``GeneratedStarSystem`` into versioned planar rails, and
``GeneratedStarSystemWorldBuilder`` materializes that hierarchy as celestial
entities and component rows. ``World`` owns stable celestial identity, mass and
radius, orbital motion, gravity participation, stellar emission, rail-model
provenance, the celestial epoch, and a prediction-basis revision.
``SOrbitalDynamics`` advances that state through content-neutral ephemeris
evaluation and versioned velocity-Verlet mechanics in one exact fixed
Simulation tick.

The production ``Engine`` schedule installs ``SOrbitalDynamics`` with the
Simulation fixed-step duration and the mechanics version selected by
``SimulationConfiguration``. The default App content still selects
``BasicWorldBuilder``, so it creates no celestial bodies for that system to
advance. Stars, planets, and moons materialized by
``GeneratedStarSystemWorldBuilder`` remain source-only rail bodies. Integrated
propagation exists in the shared mechanics and ECS adapter, but no current API
promotes a rail body, resolves contact, or publishes celestial state. The
current generation model also relies on analytic Hill, radial-clearance, Roche,
and satellite-region admission rather than a numerical N-body stability proof.

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
- ``GravitySystemEphemeris`` is the generated-system Game Content adapter that
  evaluates its rail hierarchy in stable identity order at a requested epoch.
- ``GeneratedStarSystemWorldBuilder`` validates and projects immutable Game
  Content once, then materializes ordinary celestial entities and ECS rows
  without rerunning formation during `buildWorld()`.
- ``World`` owns the celestial component stores, stable identity index,
  prescribed-ephemeris configuration, authoritative epoch, and
  prediction-basis revision.
- ``PlanarEphemerisEvaluator`` evaluates a validated, content-neutral rail
  hierarchy at an absolute epoch.
- ``PlanarOrbitalDynamicsStepper`` owns the versioned deterministic mechanics
  for prescribed and integrated bodies without depending on ECS or Game Content.
- ``SOrbitalDynamics`` adapts World-owned state into detached mechanics input,
  validates the result, and commits the complete celestial step.

The authoritative mutation path belongs inside ``SimulationRuntime``. The
implemented ECS slice establishes Simulation ownership of celestial time and
orbital state. Collision facts, authority transitions, and completed celestial
publications remain future Simulation work. Detached calculations may use the
shared mechanics, but only scheduled Simulation work may commit a result to
``World``. A future celestial publication should use a purpose-specific
Simulation-owned Snapshot rather than turn ``SimulationPresentationSnapshot``
into an exhaustive copy of World.

## Authoritative Celestial ECS State

Every celestial entity has four mandatory World-owned component rows:

| Component | Authoritative fact |
| --- | --- |
| ``CCelestialIdentity`` | Stable ``CelestialBodyID`` and closed physical kind |
| ``CMassiveBody`` | Positive physical mass and collision radius |
| ``COrbitalMotion`` | Absolute planar state and its exclusive advancement authority |
| ``CGravityParticipation`` | Independent gravity-source and gravity-receiver roles |

A stellar entity also has ``CStellarEmission`` for bolometric luminosity,
effective temperature, and XUV fraction. ``CelestialBodyIndex`` maps persistent
body identity to the session-local ``EntityID`` and publishes strict ascending
body order independently of entity or component insertion order.
``CelestialTimeline`` retains the epoch shared by every committed orbital row
and the monotonic ``CelestialPredictionBasisRevision`` used to invalidate older
predictions after a future intervention.
``CelestialEphemerisConfiguration`` retains the analytic model version required
to interpret prescribed roots and rails. Integrated-only Worlds do not require
that resource because their motion does not depend on an analytic ephemeris.

``Star``, ``Planet``, ``Moon``, ``Asteroid``, and ``Comet`` are final typed Game
Content facades over those rows. ``PCelestialBody`` exposes live physical,
orbital, and gravity facts for Game Content and tools, while systems use the
component stores and index directly. ``PStellarEmitter`` adds live stellar
emission access. The entity objects do not retain a second copy of celestial
state.

``COrbitalMotion/Authority`` separates a body's physical kind from the policy
that advances it:

- `.ephemerisRoot` evaluates the fixed root state.
- `.keplerianRail` evaluates and composes one parent-relative analytic rail.
- `.integrated` advances state through the numerical mechanics.

``GravityParticipation`` separately selects `.none`, `.sourceOnly`,
`.receiverOnly`, or `.sourceAndReceiver`. Generated stars, planets, and moons
start as source-only ephemeris bodies. The shared mechanics can also represent
an integrated gravitational test particle or a mutually interacting integrated
massive body without changing its celestial kind.

## Implemented Planar Rail Model

The implemented rail model constrains center-of-mass motion to one system plane.
The Render projection may remain fully three-dimensional: planets can be
spheres, axial tilt and spin may be three-dimensional, and terrain, rings,
effects, and cameras may extend outside the plane. Those presentation
choices do not change the authoritative orbital plane.

The model uses `Double` physical values rather than the current `Float`
presentation transforms. Its domain separates:

- ``CelestialEpoch``
- ``PlanarPosition``
- ``PlanarVelocity``
- ``PlanarStateVector``
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
orientation, hierarchy, or propagation output requires a new
``CelestialDynamicsModelVersion`` rather than a silent change to an existing
version. ``GeneratedStarSystemWorldBuilder`` preserves the selected version in
``CelestialEphemerisConfiguration`` when it materializes prescribed ECS state.

## Shared Kepler Propagation

``PlanarKeplerPropagationKernel`` advances a bound elliptical rail to an
absolute ``CelestialEpoch`` and returns its parent-relative
``PlanarStateVector``. One implementation owns anomaly solving and conversion
into planar position and velocity.

``GravitySystemEphemeris`` maps generated identities and rails into one
``PlanarEphemerisDefinition`` and delegates evaluation to
``PlanarEphemerisEvaluator``. The shared evaluator uses the kernel
hierarchically:

1. The star defines the root frame.
2. Each planet evaluates relative to the star.
3. Each moon evaluates relative to its parent planet.
4. The ephemeris adds parent state to child state to produce system-plane state.

This is a deterministic hierarchical ephemeris, not coupled N-body evolution.
Rail bodies do not exchange momentum or perturb one another. Analytic rail
evaluation therefore remains bounded and drift-free over ordinary use
until gameplay changes a body's advancement authority. Integrated bodies use
the versioned numerical mechanics when they must respond to perturbations.

The authoritative ECS path uses the same evaluator directly. Its input is a
strictly ordered hierarchy of ``CelestialBodyID`` values, one fixed root, and
parent-relative ``PlanarKeplerianRail`` values. It does not depend on generated
star-system types, entity facades, component stores, or Runtime state.
Construction rejects missing or multiple roots, duplicate or unordered
identities, missing parents, and hierarchy cycles before evaluation. The
generated Game Content path and fixed-tick Simulation path therefore share one
hierarchy-composition algorithm.

## Versioned Numerical Orbital Step

``PlanarOrbitalDynamicsStepper`` advances detached ``PlanarOrbitalBody`` inputs
through one positive finite interval. ``PlanarOrbitalDynamicsModelVersion``
currently selects `.velocityVerletV1`; save and replay provenance must retain
that version because force order or integration changes can alter results.

The V1 step has this fixed sequence:

1. Validate strict body-identity order, unique identities, mass, radius, state,
   source mass, and step duration.
2. Visit each unordered body pair once and accumulate starting acceleration in
   stable order.
3. Advance integrated positions through the velocity-Verlet position equation;
   use the caller-supplied exact ending state for prescribed bodies.
4. Re-evaluate pair gravity at the ending positions.
5. Advance integrated velocities from the average endpoint acceleration and
   return every ending state in the input identity order.

Only an integrated receiver accumulates acceleration. A prescribed source can
move between exact ephemeris endpoints without receiving numerical recoil. An
integrated `.sourceAndReceiver` body participates on both sides of a pair, while
a `.receiverOnly` body behaves as a gravitational test particle. Contact for
an interacting pair at either endpoint is a typed refusal; the stepper does not
soften singularities, resolve impact, or mutate its input.

## Fixed-Tick ECS Commit

``SOrbitalDynamics`` is the thin ECS adapter above the shared ephemeris and
stepper. For one configured tick duration it:

1. validates the indexed celestial component topology;
2. derives the next representable ``CelestialEpoch``;
3. requires and dispatches the World-selected analytic model when prescribed
   bodies exist;
4. evaluates every prescribed root and rail at the current and next epochs;
5. constructs strict-order detached inputs for prescribed and integrated bodies;
6. invokes the selected ``PlanarOrbitalDynamicsStepper``;
7. validates result version and body order; and
8. commits every ``COrbitalMotion`` row before committing
   ``CelestialTimeline``.

All typed validation, ephemeris, contact, and mechanics failures occur before
World mutation, so a refused step leaves the last committed celestial state
intact. The final row updates and timeline update form one logical commit under
Simulation's serialized fixed-tick authority. The invariant `PSystem` entry
point currently treats a refusal as a precondition failure because collision
resolution and event publication do not exist yet; focused callers can use the
typed `advance(world:)` operation.

The system owns a `Double` step duration and deliberately ignores the legacy
`Float` `PSystem` delta parameter. Production ``Engine`` construction derives
that duration from ``SimulationRuntime/fixedTimeStep`` and obtains the model
version from ``SimulationConfiguration``. The complete injected-schedule
initializer still leaves those values explicit for focused tests.

## Determinism and Persistence

The gravity projection has a deterministic address independent of wall time,
render cadence, Swift hashing, or collection iteration order. Stable source-body
identity and the rail-model version determine body-specific phase and
orientation. Hierarchy and ephemeris evaluation use stored stable body order.

``GeneratedGravitySystem`` is `Codable`, but decoding does not establish trust.
A persistence boundary must call ``GeneratedGravitySystem/validate()`` before
constructing an ephemeris or materializing a World.
Validation checks model admission, finite star and body facts, stable identity
order, hierarchy, periapsis clearance from each primary, canonical angles,
common epoch, exact seed-derived phase, standalone source gravitational
parameters, and rederived two-body gravitational parameters. It does not
authenticate bytes, replay star-system formation, or rederive retained source
mass, radius, semimajor axis, or eccentricity.

Persisted gameplay state will need more than the original generation seed. A
future save should retain:

- the complete resolved generated system
- the celestial-dynamics model version
- the authoritative celestial epoch and dynamic state
- accepted interventions and perturbation events
- periodic dynamic checkpoints when replay cost or chaotic divergence requires
  them

The implemented ECS values already separate the required provenance:
``CelestialBodyID`` survives World reconstruction, ``COrbitalMotion`` retains
rail or integrated authority beside absolute state, ``CelestialTimeline``
retains epoch and prediction-basis revision,
``CelestialEphemerisConfiguration`` identifies the analytic rail contract, and
``PlanarOrbitalDynamicsModelVersion`` identifies the numerical contract. A
complete save boundary and replay coordinator do not yet serialize and restore
that collection as one validated session value.

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

## Integrated Bodies and Proposed Authority Transitions

Versioned mechanics for mutually interacting integrated bodies are implemented.
An integrated `.receiverOnly` body can respond to source-only rails evaluated at
exact endpoint epochs without perturbing them. Integrated
`.sourceAndReceiver` bodies can interact under mutual gravity.

Authority transitions are not implemented. ``COrbitalMotion/Authority`` is
immutable after construction, and no current Simulation API performs a
rail-to-integrated transition, increments
``CelestialPredictionBasisRevision``, or publishes the corresponding
invalidation event.

A planet-scale projectile or other meaningful gravitational intervention should
promote the coupled massive hierarchy at an exact Simulation boundary:

1. Evaluate every affected rail at the transition epoch.
2. Convert the hierarchical states into one momentum-consistent dynamic state.
3. Apply the accepted spawn, impulse, or collision event.
4. Advance all promoted massive bodies through one versioned N-body policy.
5. Advance the prediction-basis revision for work derived from the former rails.

The first promotion model should remain dynamic. Automatic re-railing requires
orbit fitting, hierarchy selection, resonance handling, qualification, and
continuity rules and remains proposed.

Gravity determines contact, capture, exchange, and ejection. Detailed impact
outcomes such as fragmentation, atmosphere stripping, heating, debris, and
remnant formation belong to a separate versioned collision model.

## Proposed Belts and Comets

``Asteroid`` and ``Comet`` now provide final typed facades for authored
celestial ECS bodies. ``GeneratedStarSystemWorldBuilder`` currently creates only
the generated star, planets, and moons; star-system generation still does not
produce a belt resource, resolved asteroid population, or active comets.

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
- pinned V1 phase and orientation values plus complete multi-seed projection
  fingerprints
- complete projected body count and selected retained planet and moon orbit facts
- parent-plus-child hierarchical position and velocity composition
- hostile system validation for body order, duplicate identity, missing parents,
  corrupted phase, standalone gravitational parameters, and periapsis contact
- validated persistence boundaries for rails, epochs, positions, velocities,
  and derived orbital cadence
- circular closure, quarter-orbit states, eccentric apsides, conserved energy,
  and angular momentum
- content-neutral ephemeris validation, stable-order root/planet/moon
  composition, and detached absolute state evaluation
- versioned velocity-Verlet propagation for mutual integrated masses and a
  receiver-only test particle against a prescribed source, plus strict-order,
  contact, nonfinite-state, and no-input-mutation checks
- stable celestial identity indexing, live entity-facade reads, required
  celestial component registration, stellar value validation, and monotonic
  timeline state
- generated-system materialization into indexed celestial rows and exact rail
  advancement through the production Engine schedule
- successful ``SOrbitalDynamics`` commit agreement with the shared stepper,
  typed refusal without mutation, and empty-World behavior

Additional coverage should exercise multi-tick rail and integrated commits
through ``SimulationRuntime``, celestial publication once that boundary exists,
authority transitions, collision outcomes, massive-body conservation, and
generated-system stability ensembles.

## Current Limits

The implemented slices do not provide:

- default Game Content selection of ``GeneratedStarSystemWorldBuilder``
- celestial state in ``SimulationPresentationSnapshot`` or another published
  Simulation-owned celestial snapshot
- rail-to-integrated authority transitions or prediction-basis events
- collision resolution or event publication after the stepper reports contact
- gameplay bodies or propulsion
- generated asteroid belts, resolved asteroid populations, or active comets
- automatic stability certification
- arbitrary three-dimensional center-of-mass motion
- general relativity, tides, oblateness, atmospheric drag, or impact
  hydrodynamics

## Related Architecture

- <doc:Star-System-Generation>
- <doc:Star-System-Generation-Calibration>
- <doc:Game-Content-Architecture>
- <doc:Engine-Architecture>
- <doc:System-Scheduling>
- <doc:Runtime-Architecture>
- <doc:Runtime-Communication>
- <doc:Rendering-Architecture>
