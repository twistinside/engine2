# Star System Generation

Engine2 generates a star system once as immutable Game Content. The implemented
baseline derives planets and significant moons from a versioned stellar and disk
model, conserves material through formation, evolves present-day environments,
and validates the resolved result before any Runtime receives it.

## Status

Implemented baseline.

The current `coreAccretionLiteV1` model is a deterministic population-synthesis
approximation. It resolves a gravitationally admitted disk, local formation,
bounded dynamical outcomes, and finite atmosphere budgets. It is deliberately
more causal than choosing a final planet kind from a weighted table and
deliberately smaller than a numerical N-body or radiative-climate model.

This article explains ownership, workflow, invariants, and output semantics. See
<doc:Star-System-Generation-Calibration> for the canonical V1 distributions,
coefficients, equations, deterministic draw order, and numerical limits.

## Reading Guide

- Start with [Ownership and Lifecycle](#Ownership-and-Lifecycle) and
  [Resolved Output](#Resolved-Output) for the architectural boundary.
- Use [Determinism Contract](#Determinism-Contract),
  [Validation and Failure](#Validation-and-Failure), and
  [Persistence and Model Changes](#Persistence-and-Model-Changes) for saved data.
- Follow [Generation Workflow](#Generation-Workflow) through
  [Physical Classifications](#Physical-Classifications) for the causal model.
- Read [Verification](#Verification), [Future Integration](#Future-Integration),
  and [Scientific Context](#Scientific-Context) for confidence and limitations.

## Purpose

The generator answers physical questions before gameplay or rendering assigns
meaning to the result:

- What star formed, how old is it, and how luminous is it now?
- How much gas and condensed material did its disk contain?
- Did the sampled mass-radius disk remain above the V1 gravitational-stability
  floor?
- What iron, silicate, water, other-volatile, and hydrogen-helium masses remain
  in each final body?
- How much of each condensed component remains in published bodies, omitted
  survivors, or unaccreted annuli?
- How many embryo lineages merged into each final planet?
- Which lineages and material were ejected, accreted by the star, or stripped
  into unresolved collision debris?
- Which present orbits satisfy the baseline construction filter?
- How strongly does the current star irradiate each body?
- How much primordial envelope survives the star's early high-energy output?
- Does the visible boundary remain solid, or does a deep envelope hide it?
- Is accessible water dry, frozen, partly liquid, globally liquid, or steam?
- Can a significant moon occupy a conservative Roche-to-Hill stability region?

The output retains resolved facts plus system-level construction provenance. V1
does not retain each embryo's birth orbit, accretion history, or migration path.
A later gameplay layer can select or score systems without changing how those
systems physically form. A later Render implementation can derive appearances
without becoming the authority for mass, composition, orbit, temperature, or
atmosphere.

## Ownership and Lifecycle

``StarSystemGenerator`` is a pure Game Content construction utility.

It is not:

- a Runtime
- an ECS System
- a source of wall-clock work
- a mutable simulation resource
- a renderer or asset generator
- a gameplay-category selector

One call to `generate(seed:)` constructs local mutable formation state and
returns one immutable ``GeneratedStarSystem``. The generator holds only its
immutable ``StarSystemGenerationPolicy``. It owns no task, actor, cache, file,
GPU object, global registry, or random singleton.

The current ``PGameContent`` contract remains unchanged. It deliberately
contains a world builder, Simulation configuration, and Render catalog. A future
`GeneratedStarSystemWorldBuilder` can accept an already resolved and validated
system and project it into ECS state. Generation should not run inside
`PWorldBuilder.buildWorld()` because that nonthrowing operation could hide a
generation failure or rerun generation during world reconstruction.

```text
Game Content seed + policy
          |
          v
StarSystemGenerator
          |
          v
validated GeneratedStarSystem
          |
          +----> persistence or inspection
          |
          `----> future GeneratedStarSystemWorldBuilder
                          |
                          v
                  authoritative Simulation state
```

This boundary follows <doc:Game-Content-Architecture>: construction input and
resolved descriptions remain Game Content, while future Runtime-owned state is
created only at the Runtime's existing construction boundary.

## Supported Model

V1 supports:

- exactly one main-sequence star from `0.5...1.2` solar masses
- stellar metallicity, present age, luminosity, radius, effective temperature,
  and a slow, median, or fast early-activity track
- one mass-radius-correlated, exponentially tapered gas-and-solid disk admitted
  through an annular Toomre-stability bound
- 128 logarithmic disk annuli
- up to 64 fully funded embryos
- 96 bounded gas-disk formation epochs
- simultaneous solid claims, cooling- and supply-limited primordial gas
  capture, local gap-aware migration toward an inner trap or snow line, and
  erosive gas-disk collisions whose solid debris can be reaccreted
- bounded post-disk collisions, scattering, ejections, and stellar accretion
  followed by deterministic Hill and radial-clearance fallbacks
- a sampled `0...9` output capacity, detailed output for the most massive
  eligible survivors, and an aggregate composition-and-ancestry ledger for
  every omitted survivor
- present-day orbit-averaged irradiation, finite-budget boil-off,
  core-powered and energy-limited envelope loss, radius, optional
  exposed-surface pressure, albedo, and zero-dimensional visible-boundary
  temperature
- orthogonal physical classifications
- a bounded set of significant regular or giant-impact moons
- per-component solid and aggregate hydrogen-helium conservation ledgers with
  explicit post-disk destinations

V1 does not support:

- binary, multiple, evolved, or remnant stars
- stellar-track table interpolation
- individual orbits, environments, classifications, or moons for residual
  bodies, or a resolved planetesimal population outside the funded seed and
  feeding-zone model
- planetesimal velocity distributions, pebble accretion, resonant capture, or
  general torque reversals beyond the inner-trap and snow-line attractors
- orbital phase, encounter geometry, fragmentation cascades, debris-body
  resolution, or a free-floating-planet catalog
- a numerical N-body stability proof
- detailed planetary interiors, contraction, clouds, circulation, or chemistry
- spatial climate, seasons, obliquity, rotation, tides, or radiogenic heating
- captured irregular moons, rings, or spatial debris belts
- biospheres, civilizations, resources, economy, or gameplay value
- ECS, Runtime, camera, or Render integration

Unimplemented effects are not hidden random corrections. The V1 result remains
an inspectable product of the implemented phases.

## Resolved Output

``GeneratedStarSystem`` stores:

- the ``StarSystemSeed``
- the ``StarSystemGenerationModelVersion``
- the complete ``StarSystemGenerationPolicy``
- one ``GeneratedStar``
- one ``GeneratedProtoplanetaryDisk`` summary
- one ``StarSystemFormationLedger``, including the sampled resolved-planet
  capacity
- semimajor-axis-ordered ``GeneratedPlanet`` values

Every published planet stores stable identity, conserved component masses,
radius, reduced Keplerian orbit, environment, orthogonal physical state,
significant moons, and progenitor count. Every moon stores its formation origin,
composition, radius, parent-relative orbit, and the minimum and maximum
semimajor-axis bounds used by validation. The disk and ledger retain initial and
unaccreted solid compositions so iron, silicate, water, and other volatiles can
close independently.

The formation ledger also distinguishes post-disk ejected material,
star-accreted material, and collision debris that remains in the system without
becoming a resolved body. Event and ancestry counts let validation reconcile
the funded embryo population with the surviving planets. V1 samples an output
capacity from `0...9`, then considers survivors with at least `0.1` Earth masses
of pre-moon solids. It selects up to that capacity by descending pre-moon solid
mass; an exact tie ranks the smaller stable identity first. The published array
remains ordered by semimajor axis. Every other survivor contributes its complete
composition, body count, and progenitor count to the residual fields. This
includes subthreshold survivors and eligible survivors beyond the sampled
capacity. A zero capacity therefore produces a valid system with no resolved
planets. V1 does not force a fallback planet.

The capacity controls resolved output and population shape. It is not a
physical nine-body law. Formation and dynamical clearing can leave more than
nine survivors; the output aggregates those beyond the capacity instead of
discarding their mass or ancestry.

Residual-body aggregation happens before present-day atmosphere evolution and
moon extraction. The aggregate therefore has no resolved orbit, radius,
environment, escaped-atmosphere history, or moon system. Its hydrogen-helium
remains in the residual composition branch of the gas ledger.

The output is `Codable`, `Equatable`, and `Sendable`. Codable synthesis does not
validate arbitrary decoded bytes. A persistence boundary must call
``GeneratedStarSystem/validate()`` after decoding. Validation checks the
canonical model, replays seed-derived star and disk facts, rederives present
body environments, and checks structural and conservation invariants. It does
not authenticate the bytes or replay every formation epoch.

The construction call makes policy selection visible:

```swift
let generator = StarSystemGenerator(policy: .coreAccretionLiteV1)
let system = try generator.generate(
    seed: StarSystemSeed(rawValue: 0xC0FFEE)
)

try system.validate()
```

The initializer has no implicit production policy. A caller deliberately
selects the canonical calibration it intends to persist. V1 rejects a decoded
or altered policy even when each individual value is numerically valid.

## Units and Numeric Domains

Formation and authoritative Simulation translation use `Double`. Completed
presentation snapshots narrow positions to the Render layer's `Float` domain.

The stored domain quantities use one canonical base unit and named projections:

| Type | Stored unit | Named projections |
| --- | --- | --- |
| ``AstronomicalMass`` | kilogram | Earth masses, solar masses |
| ``AstronomicalDistance`` | meter | Earth radii, solar radii, astronomical units |
| ``AstronomicalDuration`` | second | megayears, gigayears |
| ``StellarLuminosity`` | watt | solar luminosities |
| ``ThermodynamicTemperature`` | kelvin | kelvin |
| ``SurfacePressure`` | pascal | bars |
| ``OrbitalEccentricity`` | dimensionless | raw value in `0..<1` |

``CelestialMassComposition`` keeps five nonnegative masses:

```text
iron
silicate
water
other volatiles
hydrogen and helium
```

Water and other volatiles include material in the interior, condensed phases,
and any secondary atmosphere. `PlanetaryEnvironment.atmosphereMass` is a phase
partition estimate, not mass added on top of the composition. Primordial
hydrogen and helium is separate because it is accreted and escaped through a
different model.

## Determinism Contract

The complete deterministic address is:

```text
root seed
  + model-version raw value
  + named random-domain raw value
  + optional stable body discriminator
```

``StarSystemRandomStream`` derives the star-system-specific address and delegates
integer production to the reusable ``SplitMix64RandomNumberGenerator``. Unit
uniform sampling uses the upper 53 random bits and multiplies by `2^-53`.
Normal sampling uses Box-Muller without a cached spare. Log-normal and Rayleigh
values derive only from those operations.

The generator never uses:

- `SystemRandomNumberGenerator`
- `Double.random`
- Swift `Hasher`
- `UUID`
- wall time
- process-global mutable state
- dictionary iteration order

Star, disk, embryo placement, formation collision, post-disk dynamical clearing,
orbital excitation, and moon generation have distinct stream domains. Final-body
orbital and moon draws include stable body identity. A post-disk encounter
stream includes the ordered body identities and encounter sequence. Adding a
moon draw cannot shift the generated star or disk.

Within a phase, floating-point reduction order is part of V1. Formation is
serial and arrays are sorted by stable identity before claims. The contract is
exact reproduction on the pinned supported Swift toolchain and architecture.
`log`, `exp`, `pow`, and related library implementations can differ across
toolchains. Persist the resolved system instead of assuming bit-identical
seed-only regeneration forever.

This in-place rewrite establishes the V1 compatibility baseline before its
first persistence freeze. After that freeze, any change to these inputs
requires a new model version:

- a distribution or calibration
- a formula
- phase order
- collection ordering or tie-break rule
- random-domain raw value
- number or order of random draws
- numerical fallback

## Generation Workflow

`StarSystemGenerator.generate(seed:)` names the physical phases directly:

```text
generate present star and retained early activity
  -> sample a correlated disk and reject gravitationally unsupported structures
  -> normalize its represented annular reservoirs
  -> fully fund embryos from disk solids
  -> evolve simultaneous solid claims and supply-limited gas capture
  -> migrate through local disk zones and collide during the gas-disk lifetime
  -> disperse remaining gas
  -> resolve close post-disk pairs by collision, scattering, ejection, or stellar loss
  -> assign and damp orbital excitation
  -> sample resolved-planet capacity, select eligible survivors, and aggregate omissions
  -> partition significant moon material
  -> subtract finite primordial-atmosphere budgets and project secondary atmosphere
  -> resolve present environments
  -> build conservation and dynamical-destination ledgers
  -> validate complete immutable result
```

Each phase is a focused value-semantic collaborator. Mutable annuli, embryos,
and moon seeds remain internal construction state and cannot escape in the
resolved model.

## Star Phase

``MainSequenceStarGenerator`` samples a truncated power-law mass, metallicity,
age, and activity regime. It derives luminosity, lifetime, radius, effective
temperature, and present XUV fraction from explicit analytic V1 proxies.

These equations are not bundled stellar tracks. They make luminosity and age
causal inputs to the rest of the system while preserving a clean future seam for
tabulated evolution such as MIST. The disk phase separately derives a brighter
formation-luminosity proxy so the condensation boundary does not incorrectly use
only the mature star.

## Conserved Disk Phase

``ProtoplanetaryDiskGenerator`` jointly samples gas-to-star mass ratio,
characteristic radius, and surface-density exponent. Characteristic radius
scales with disk mass to the `0.625` power before independent radius scatter,
so a massive disk is normally more extended instead of independently dense.
The generator evaluates every candidate's 128 annuli and accepts it only when
the minimum Toomre `Q` is at least `1.4`. It makes at most 16 attempts, then
uses the minimum supported disk-mass ratio with the last sampled shape. The
canonical policy caps the unconstrained ratio at `0.16`.

The represented disk extends from the stellar inner edge through the smaller
of `150 AU` and five characteristic radii. The stored gas reservoir is the
analytic tapered-disk mass fraction inside those edges, not the mass of an
unbounded disk. Solids are a metallicity-dependent fraction of that represented
gas reservoir.

The unnormalized mass weight for one annulus is:

```text
w(a) = 2 pi a delta-a
       (a / Rc)^(-p)
       exp(-(a / Rc)^(2 - p))
```

Numerical normalization makes all represented-annulus weights sum to one. Each
weight receives the same fraction of total gas and total solids, so the discrete
disk exactly reproduces both sampled reservoirs before floating-point tolerance.

The water snow line is based on the V1 formation luminosity. Forty-five percent
of disks begin with dry inner solids. The other disks receive a seeded
log-uniform trace-to-water-rich inner inventory that represents unresolved
hydrated material and late radial delivery. Composition then blends across
`0.8...1.2` snow-line radii to an outer mixture containing water and colder
volatiles. Material keeps this composition after migration. Moving an icy core
inward does not retroactively turn its formation material into dry rock.

## Embryo Funding

Embryo placement advances outward through at most `40 AU` with the larger of a
deterministic logarithmic spacing jitter and an eight-mutual-Hill-radius seed
spacing. Each placement succeeds only when its five-annulus neighborhood can
supply the complete configured `0.01`-Earth-mass seed. One common withdrawal
fraction preserves the neighborhood's local component mixture.

An underfunded placement withdraws nothing and creates no body. Generation
fails with `noFundedEmbryos` only if placement creates no fully funded embryo.
Identity is assigned monotonically to funded embryos and retained through later
sorting. A collision remnant keeps the smaller progenitor identity and sums
progenitor counts.

V1 does not promote remaining annulus solids into a second embryo or
planetesimal population. Those solids can feed the funded embryos during the
96 epochs or remain unaccreted in the final ledger. This annulus reservoir is
distinct from `residualBodyComposition`, which aggregates actual surviving
formation bodies omitted by eligibility or sampled output capacity. Neither
aggregate provides a spatially resolved belt or individual residual-body facts.

## Simultaneous Solid Accretion

Each of 96 epochs follows this ordering:

1. Sort embryos by stable identity.
2. Snapshot all embryo and annulus values.
3. Calculate every solid claim against that snapshot.
4. Sum all claims for each annulus.
5. Scale contested claims proportionally when their sum exceeds one annulus.
6. Apply every component-mass allocation.
7. Calculate and apply cooling-, hydrodynamic-, viscous-, and gap-limited
   gas-envelope claims.
8. Apply bounded local migration toward the selected disk attractor.
9. Disperse one epoch of unbound disk gas.
10. At every eighth epoch, collide bodies inside the formation Hill threshold
    and return stripped material to explicit destinations.

No annulus is debited while the next embryo's claim is being calculated. That
rule prevents storage order from becoming hidden accretion priority.

An embryo's solid feeding zone is the larger of eight Hill radii and four
percent of its orbital radius. A tapered claim decreases toward the feeding-zone
edge. Every material component is transferred with the annulus mixture, and no
claim can make an inventory negative. The claim is a rate integrated over the
actual epoch duration, so a longer-lived otherwise identical disk can grow more
mass before dispersal.

## Primordial Gas and Migration

Only cores of at least `0.3` Earth masses request primordial gas. Cooling sets
an attached-envelope demand from core mass and elapsed disk time; a
Kelvin-Helmholtz timescale controls how much of that demand can be realized in
one epoch. Once the envelope reaches `0.45` of core mass, the larger runaway
demand is eligible.

Demand is not an allocation guarantee. The request is capped by gas in a local
capture zone, a hydrodynamic response, a viscous-throughput estimate, and a gap
flow factor. The disk aspect ratio, `0.002` turbulent-viscosity proxy, body-star
mass ratio, and Hill radius determine gap opening and depth. Claims remain
simultaneous and are scaled proportionally when embryos contest one annulus.

Migration uses the remaining gas fraction in the nearest annulus rather than a
system-wide gas fraction. A non-gap-opening body moves toward whichever is
closer in log radius: the inner trap or snow line. It can therefore move inward
or outward. A gap-opening body uses a depth-reduced rate capped by the local
viscous rate and does not move outward. Every epoch caps the fractional step at
three percent. The inner trap is the larger of `1.8` inner-edge radii and `0.18`
snow-line radii.

After capture and migration, every annulus loses the exponential fraction for
that epoch's duration relative to the sampled disk lifetime. After the final
epoch, the generator disperses all gas still in the disk. Captured gas remains
on bodies until present-day escape; all other gas enters the dispersed ledger.

## Collisions and Final Architecture

The mutual Hill radius for adjacent bodies is:

```text
RH,m = ((m1 + m2) / (3 Mstar))^(1/3) * (a1 + a2) / 2
delta = (a2 - a1) / RH,m
```

Formation treats `delta < 3.5` as a collision. The remnant retains
`98.5...100%` of the combined solid mass and `55...90%` of hydrogen-helium.
Stripped solids return to the nearest annulus and can be accreted later;
stripped hydrogen-helium enters dispersed gas. The remnant orbit preserves the
circular, star-dominated angular-momentum approximation:

```text
aRemnant = ((m1 sqrt(a1) + m2 sqrt(a2)) / (m1 + m2))^2
```

Post-disk clearing treats the first semimajor-axis-ordered pair below the
required mutual-Hill spacing as an encounter:

- `12` mutual Hill radii for ordinary pairs
- `15` mutual Hill radii when either body is at least `30` Earth masses

One pair-addressed random stream draws once against ordered conditional
thresholds: stellar accretion first, ejection among survivors, collision among
the remainder, and scattering otherwise. Encounter severity, stellar proximity,
and an escape-to-orbit-speed proxy determine those probabilities. Ejection
normally removes the lower-mass member.
Scattering tries four bounded separations inside the modeled disk range while
preserving the same circular angular-momentum approximation. A failed scatter
becomes a collision. Post-disk collision retention falls as encounter severity
rises, with a `90%` solid floor and `15%` hydrogen-helium floor. Collision
debris stays in the system but is not assigned a resolved body. Ejected and
star-accreted composition leave the planetary architecture and retain separate
ledger destinations.

The encounter loop is bounded by the larger of 64 and the square of the maximum
embryo count. If that limit is reached, the deterministic fallback ejects the
smaller body from each remaining insufficiently spaced pair. The result therefore
satisfies the persisted Hill-spacing filter without claiming an N-body proof.

Each final identity addresses its own random stream. Ordinary bodies receive a
Rayleigh eccentricity scale of `0.02`; giants and bodies with at least four
progenitors use `0.05`. Inclination uses a bounded normal draw. The resolver
then scales all eccentricities by `0.8` for at most 32 passes until adjacent
apoapsis-periapsis separation exceeds `3.5` mutual Hill radii. V1 persists the
formation-merger and radial-clearance multipliers separately even though both
initially equal `3.5`. Circular orbits are the deterministic final fallback.

The encounter probabilities, analytic scattering, and Hill filter are
population approximations. They do not replace a long-duration numerical
integration or retain encounter phase geometry.

## Significant Moon Phase

V1 generates moons only from material removed from the parent body:

- A body of at least `10` Earth masses with at least ten percent hydrogen and
  helium can form one to four regular moons. Their combined budget is the
  smaller of two percent of parent solids and `2e-4` of total parent mass.
- A body with a merger history and at least `0.1` Earth masses has a 40 percent
  deterministic chance to form one giant-impact moon containing `0.2...1.5`
  percent of parent solids.

The extraction phase first requires the eccentricity-dependent prograde critical
Hill fraction to exceed the six-radius inner limit for a moon at the maximum V1
eccentricity. Moon weights are normalized, so the exact extracted solid budget
is removed from the parent and divided among moons without changing the global
solid ledger.

The fluid Roche estimate is:

```text
aRoche = 2.44 Rparent (rhoParent / rhoMoon)^(1/3)
```

The stored lower semimajor-axis bound keeps moon periapsis beyond the larger of
six parent radii and `1.05` times that estimate. The upper bound uses:

```text
fcritical = max(0.05, 0.4895 * (1 - 1.0305 eplanet - 0.2738 emoon))
amax = fcritical RHill,parent
```

V1 places moons logarithmically between those bounds. If adjacent moons cross
or lie within `3.5` mutual Hill radii, it deterministically merges the first
unstable pair and repeats. This bounded, mass-conserving repair ends when the
system is clear or only one moon remains. The eccentricity-dependent prograde
factor follows the baseline reported by Domingos, Winter, and Yokoyama.

Moon temperature and atmosphere use the parent planet's orbit around the star.
V1 does not add tidal heat or model satellite migration and resonances.

## Present-Day Evolution

``PlanetaryEnvironmentResolver`` gives the primordial envelope three finite
loss phases. A Bondi-radius comparison removes up to 90 percent during boil-off.
A core-powered budget then removes up to five percent of core mass according to
equilibrium temperature and core mass. Finally, 48 logarithmic intervals from
`0.01` Gyr to the system age subtract an absolute energy-limited XUV mass
capacity. Each interval uses the star's stored present XUV fraction, a bounded
backward activity curve, incident flux, current mass, and an updated radius.
Every phase can reduce retained hydrogen-helium to exactly zero. Removed mass
enters the escaped-gas ledger.

The orbit-averaged bolometric flux is:

```text
S / SEarth = (L / LSun) / (a^2 sqrt(1 - e^2))
```

Radius begins with a solid mass power law modified by water and other volatiles.
Gas-bearing bodies receive an age-, mass-, flux-, and envelope-dependent
inflation proxy. Hydrogen-helium-dominated bodies above 30 Earth masses use a
separate bounded giant-radius branch.

Secondary-atmosphere supply is a finite `0.0001` fraction of accessible water
and other volatiles, multiplied by a mass-dependent geologic-supply proxy. The
empirical cosmic-shoreline trend is a hard survival boundary:

```text
q = 4 log10(vescape / vescape,Earth) - log10(S / SEarth)
survives = q >= -0.25
```

The supplied phase is retained in full when it survives and is exactly zero
otherwise. This is a calibrated population boundary, not a claim that every
real body follows one deterministic law. Mass, radius, flux, and volatile
inventory still determine the modeled outcome.

For an exposed solid radius, surface pressure scales as:

```text
P / 1 bar = (Matmosphere / 8.62e-7 Earth masses)
            * (M / Earth mass)
            / (R / Earth radius)^4
```

Atmosphere mass includes retained hydrogen and helium plus the secondary phase
partition. It remains a subset of already conserved composition. A body with at
least one percent hydrogen-helium by mass or at least `100` bar at the solid
radius has an opaque visible boundary. Its public `surfacePressure` is `nil`
because V1 does not claim an accessible solid-surface pressure beneath that
envelope. The climate branch still uses a bounded visible-column proxy.

An exposed body is `airless` only when resolved atmosphere mass is exactly
zero. Every positive atmosphere below the `0.05`-bar secondary threshold is
`tenuous`; V1 does not erase a positive mass with an epsilon classification.

## Zero-Dimensional Climate

The environment resolver runs six bounded albedo-greenhouse iterations.
Effective radiative temperature is:

```text
Teq = 278.5 K * (S (1 - A))^0.25
```

The visible-boundary estimate is:

```text
Tboundary = Teq * (1 + 0.75 tau)^0.25
```

Optical depth is a bounded pressure proxy with separate exposed and opaque
branches. Albedo responds to opaque atmospheres, cold accessible water, moderate
liquid-water conditions, and very hot exposed surfaces. After six feedback
iterations, the resolver recomputes both stored temperatures from the final
stored albedo.

Accessible water produces:

- ice coverage below `260 K`
- liquid coverage between `273...373 K` when pressure is at least `0.006` bar
- steam classification above `373 K`

Opaque atmospheres publish zero exposed-boundary water coverage and the
`inaccessible` water regime. For exposed bodies, the coverage proxy maps the
accessible water mass fraction through a factor of `2,500`, allowing shallow
seas, partial coverage, and flooded surfaces without requiring water to dominate
the body's bulk mass. A water-bearing exposed body is still classified as dry
when its resolved pressure and temperature support neither liquid nor ice
coverage.

The result is not a habitable-zone or biology decision. It omits spatial
circulation, clouds, atmospheric composition, pressure-dependent boiling,
supercritical water, salinity, topography, seasons, and tidal heat.

## Physical Classifications

``PlanetaryPhysicalState`` keeps five independent axes:

| Axis | Values |
| --- | --- |
| Bulk | metal rich, rocky, volatile rich, hydrogen-helium dominated |
| Visible boundary | exposed solid, opaque atmosphere |
| Atmosphere | airless, tenuous, secondary, deep envelope |
| Thermal | frozen, temperate, hot, molten |
| Water | dry, ice covered, partial liquid, global ocean, steam, inaccessible |

These are derived summaries. They do not replace mass, composition, orbit, or
environment. In particular, the production model has no `industrial`, `lush`,
`extreme`, or other gameplay enum. A future gameplay projection can combine
several facts, apply scenario weights, or search seeds without contaminating
the physical generator.

## Conservation Ledgers

The final solid invariant is checked independently for iron, silicate, water,
and other volatiles:

```text
initial disk solids
  = retained planet and moon solids
  + unaccreted annulus solids
  + residual-body solids
  + ejected solids
  + star-accreted solids
  + post-disk collision-debris solids
```

The final hydrogen-helium invariant is:

```text
initial disk gas
  = retained planet and moon hydrogen-helium
  + residual-body hydrogen-helium
  + escaped planetary hydrogen-helium
  + dispersed disk gas
  + ejected hydrogen-helium
  + star-accreted hydrogen-helium
  + post-disk collision-debris hydrogen-helium
```

Moon material appears exactly once. It is removed from the parent before both
bodies enter `retainedSolidMass`. The disk retains its initial solid composition,
and the ledger retains unaccreted annulus, residual-body, and dynamical
compositions, so equal aggregate solid mass cannot hide a component-transfer
regression.

The ledger also records funded embryo count, sampled resolved-planet capacity,
residual body and progenitor counts, formation and post-disk collision counts,
scattering count, and removed body and progenitor counts. V1 keeps leftover
annulus solids and omitted formed survivors in distinct aggregates; it does not
invent belt locations or individual residual environments after formation.

## Validation and Failure

``GeneratedStarSystem/validate()`` rejects:

- a model version that differs from the stored policy
- a policy that is invalid or not the exact canonical calibration for its version
- star or disk facts that do not reproduce from the seed and canonical policy
- a resolved-planet capacity outside the policy bound or different from the
  seed-derived sample
- nonfinite, nonpositive, overflowing, or causally inconsistent physical values
- an invalid disk extent, component budget, lifetime, exponent, or annulus count
- duplicate, out-of-namespace, wrong-parent, or out-of-range body identities
- body, moon, progenitor, or merger counts outside their bounded ancestry ledger
- residual-body composition, body count, or progenitor count that disagree on
  whether the residual branch is empty
- aggregate residual solid mass above the eligibility boundary when capacity
  remains, or above the smallest resolved solid mass when capacity is full
- inconsistent ejection, stellar-accretion, scattering, collision-debris, or
  post-disk collision counts and composition destinations
- nonpositive body mass or radius
- a planetary periapsis inside the stellar radius
- planets not sorted by semimajor axis
- adjacent planets below required Hill spacing
- adjacent radial orbits without the required clearance
- a present radius, environment, or physical state that does not rederive from
  stored composition, orbit, star, and policy
- moon bounds that do not rederive from parent, moon, and orbital eccentricities
- a moon outside those bounds or an adjacent moon pair without Hill clearance
- a mismatch among resolved, residual, ejected, star-accreted, or merged ancestry
  and body counts
- a published planetary system whose parent-plus-moons solid mass is below the
  resolved-planet eligibility threshold
- more published planets than the persisted capacity permits
- an open component-level solid or aggregate hydrogen-helium budget

Replayed floating facts and mass comparisons use a relative tolerance of `1e-9`
with a unit absolute scale floor. Planetary Hill checks allow `1e-10` additive
slack and moon radial checks allow one micrometer. Generation itself has finite
disk-candidate, annulus, embryo, formation, encounter, evolution,
eccentricity-damping, and moon-count bounds. Moon repair strictly reduces count.
Moon extraction moves solids from a selected parent into its moons, so
validation compares their combined solid mass with the selection threshold.
Validation replays the capacity draw, requires every published planet to remain
eligible, and enforces the capacity bound. When capacity remains, residual
solids cannot average above the eligibility floor. When capacity is full,
residual solids cannot average above the smallest published parent-plus-moons
solid mass. A zero capacity has no resolved selection boundary. These aggregate
checks do not replay formation to prove that each decoded planet was among the
highest-mass eligible survivors. The generator contains no unbounded candidate
retry for a more interesting system.

## Persistence and Model Changes

Persist the complete resolved system, not only its seed.

The seed and policy are provenance and audit input. They are not a substitute
for resolved data because:

- future model versions intentionally change output
- floating-point library behavior can change between supported toolchains
- a save must remain stable after calibration improvements
- inspecting a save should not rerun formation

When loading decoded bytes:

1. Decode ``GeneratedStarSystem``.
2. Call ``GeneratedStarSystem/validate()``.
3. Reject or migrate invalid or unsupported model versions explicitly.
4. Supply the trusted resolved value to later construction code.

Validation is an integrity and compatibility check, not an authenticity proof.
Content received across a security boundary still needs the host's ordinary
authentication or signature policy.

## Verification

The normal regression gate verifies:

- pinned SplitMix64 words
- three pinned canonical resolved-system fingerprints
- independent named random addresses
- unit-uniform bounds
- exact same-seed equality
- different-seed divergence
- Codable round trip followed by validation
- canonical policy admission, identity and ancestry integrity, and hostile
  decoded-value rejection
- stellar and stable-disk calibration bounds, shared-profile Toomre admission,
  fully funded seed-mass floor, and seed replay
- resolved-capacity replay, resolved-versus-residual selection, dynamical
  outcome modes and destinations, and complete embryo ancestry closure
- paired disk-lifetime, luminosity, distance, XUV, and gravity causality
- component-level solid and aggregate gas ledger closure
- semimajor-axis ordering and mutual-Hill separation
- both moon origins, eccentric Roche/Hill bounds, and moon-pair clearance
- the mean-flux equation
- finite atmosphere-loss causality, exact-zero airless semantics, final-albedo
  temperature consistency, and opaque-boundary semantics
- the expected bulk, atmosphere, thermal, water, visible-boundary, capacity,
  and resolved-count sets across a bounded representative-seed smoke ensemble

Pinned fingerprints detect any resolved-output change; they do not decide
whether the new population is acceptable. Invariant and focused causal tests
must pass before fingerprints are deliberately replaced. The bounded
representative-seed smoke ensemble checks finite execution and coarse
reachability; it is not a calibration sample.

The normal suite intentionally avoids observational occurrence-rate claims and
wall-time assertions. Its representative seeds pin reachability, not frequency.
Release calibration requires a separate large-seed audit
that streams aggregate distributions without retaining every full system in
memory. The audit records its model version, complete policy, seed range,
toolchain, platform, failure counts, conservation residuals, dynamical
destinations, physical-state cross-tabulations, and timing. Reviewers compare
that artifact with an explicitly approved baseline; they do not infer quality
from a small passing seed set.

## Future Integration

The next physical-model steps should be versioned additions or replacements,
not silent mutation of V1:

1. Replace analytic stellar proxies with bundled stellar and XUV tracks.
2. Calibrate ensemble distributions against observational datasets.
3. Resolve the residual planetesimal and omitted-body population when a consumer
   needs individual or spatial facts.
4. Replace analytic encounters with richer impact, debris, tide, and optional
   N-body audit models.
5. Add richer interior, envelope, atmospheric chemistry, and climate tables.
6. Design authoritative celestial ECS state and a world builder that consumes
   an already resolved system.
7. Add gameplay projections over physical facts.
8. Add Render appearance descriptions and procedural surface inputs without
   making Render authoritative for physical generation.

## Scientific Context

The architecture follows the causal ordering used by planetary population
synthesis while replacing expensive differential and N-body solvers with
bounded analytic approximations:

- [Bern Generation III global formation and evolution model](https://arxiv.org/abs/2007.05561)
- [MIST stellar evolution tracks](https://arxiv.org/abs/1604.08592)
- [Pu and Wu on mutual-Hill spacing in Kepler systems](https://arxiv.org/abs/1502.05449)
- [Zahnle and Catling on the empirical cosmic shoreline](https://arxiv.org/abs/1702.03386)
- [Lopez and Fortney on sub-Neptune radius dependence](https://arxiv.org/abs/1311.0329)
- [Domingos, Winter, and Yokoyama on stable satellite regions](https://articles.adsabs.harvard.edu/pdf/2006MNRAS.373.1227D)

Those works motivate relationships and future calibration. V1's coefficients
remain Engine2 approximations unless <doc:Star-System-Generation-Calibration>
identifies them as direct definitions.

## Related Architecture

- <doc:Game-Content-Architecture>
- <doc:Engine-Architecture>
- <doc:Runtime-Architecture>
- <doc:Rendering-Architecture>
