# Star System Generation

Engine2 generates a star system once as immutable Game Content. The implemented
baseline derives planets and significant moons from a versioned stellar and disk
model, conserves material through formation, evolves present-day environments,
and validates the resolved result before any Runtime receives it.

## Status

Implemented baseline.

The current `coreAccretionLiteV1` model is a deterministic population-synthesis
approximation. It is deliberately more causal than choosing a final planet kind
from a weighted table and deliberately smaller than a numerical N-body or
radiative-climate model.

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
- What iron, silicate, water, other-volatile, and hydrogen-helium masses remain
  in each final body?
- How much of each condensed component remains in bodies or unresolved annuli?
- How many embryo lineages merged into each final planet?
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
- one exponentially tapered gas-and-solid disk
- 128 logarithmic disk annuli
- up to 64 funded embryos
- 96 bounded gas-disk formation epochs
- simultaneous solid claims, primordial gas capture, inward migration, and
  perfectly accretionary mergers
- deterministic post-disk Hill clearing
- present-day orbit-averaged irradiation, envelope loss, radius, optional
  exposed-surface pressure, albedo, and zero-dimensional visible-boundary
  temperature
- orthogonal physical classifications
- a bounded set of significant regular or giant-impact moons
- per-component solid and aggregate hydrogen-helium conservation ledgers

V1 does not support:

- binary, multiple, evolved, or remnant stars
- stellar-track table interpolation
- planetesimal velocity distributions or pebble accretion
- resonant capture, outward migration, or disk cavities beyond one inner trap
- ejections, collisions with the star, fragmentation, or impact erosion
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
- one ``StarSystemFormationLedger``
- semimajor-axis-ordered ``GeneratedPlanet`` values

Every generated planet stores stable identity, conserved component masses,
radius, reduced Keplerian orbit, environment, orthogonal physical state,
significant moons, and progenitor count. Every moon stores its formation origin,
composition, radius, parent-relative orbit, and the minimum and maximum
semimajor-axis bounds used by validation. The disk and ledger retain initial and
unaccreted solid compositions so iron, silicate, water, and other volatiles can
close independently.

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

Formation uses `Double` throughout. Celestial values do not reuse the current
Simulation and Render `Float` transforms.

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

``StarSystemRandomStream`` applies a pinned SplitMix64 sequence. Unit uniform
sampling uses the upper 53 random bits and multiplies by `2^-53`. Normal
sampling uses Box-Muller without a cached spare. Log-normal and Rayleigh values
derive only from those operations.

The generator never uses:

- `SystemRandomNumberGenerator`
- `Double.random`
- Swift `Hasher`
- `UUID`
- wall time
- process-global mutable state
- dictionary iteration order

Star, disk, embryo placement, formation, orbital excitation, and moon generation
have distinct stream domains. Final-body orbital and moon draws include stable
body identity. Adding a moon draw cannot shift the generated star or disk.

Within a phase, floating-point reduction order is part of V1. Formation is
serial and arrays are sorted by stable identity before claims. The contract is
exact reproduction on the pinned supported Swift toolchain and architecture.
`log`, `exp`, `pow`, and related library implementations can differ across
toolchains. Persist the resolved system instead of assuming bit-identical
seed-only regeneration forever.

Any change to these inputs requires a new model version:

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
  -> generate and normalize protoplanetary disk
  -> fund embryos from disk solids
  -> evolve simultaneous solid and gas accretion
  -> migrate and merge during gas-disk lifetime
  -> disperse remaining gas
  -> clear insufficiently spaced final planets
  -> assign and damp orbital excitation
  -> partition significant moon material
  -> evolve bodies to their present environments
  -> build conservation ledger
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

``ProtoplanetaryDiskGenerator`` samples gas mass, solid fraction, lifetime,
characteristic radius, and surface-density exponent. It builds logarithmic
annulus edges from the inner disk to `min(40 AU, 3 Rc)`.

The unnormalized mass weight for one annulus is:

```text
w(a) = 2 pi a delta-a
       (a / Rc)^(-p)
       exp(-(a / Rc)^(2 - p))
```

Numerical normalization makes all annulus weights sum to one. Each weight
receives the same fraction of total gas and total solids, so the discrete disk
exactly reproduces both sampled reservoirs before floating-point tolerance.

The water snow line is based on the V1 formation luminosity. Forty-five percent
of disks begin with dry inner solids. The other disks receive a seeded
log-uniform trace-to-water-rich inner inventory that represents unresolved
hydrated material and late radial delivery. Composition then blends across
`0.8...1.2` snow-line radii to an outer mixture containing water and colder
volatiles. Material keeps this composition after migration. Moving an icy core
inward does not retroactively turn its formation material into dry rock.

## Embryo Funding

Embryo placement advances outward with a deterministic logarithmic spacing
jitter. Each placement withdraws at most the configured seed mass from the five
nearest annuli. Withdrawal uses one common fraction across those annuli, which
preserves their local component mixture.

An unfunded placement creates no body. Generation fails with
`noFundedEmbryos` only if the complete disk cannot fund any embryo. Identity is
assigned monotonically to funded embryos and retained through later sorting. A
merger keeps the smaller progenitor identity and sums progenitor counts.

## Simultaneous Solid Accretion

Each of 96 epochs follows this ordering:

1. Sort embryos by stable identity.
2. Snapshot all embryo and annulus values.
3. Calculate every solid claim against that snapshot.
4. Sum all claims for each annulus.
5. Scale contested claims proportionally when their sum exceeds one annulus.
6. Apply every component-mass allocation.
7. Calculate and apply gas-envelope claims.
8. Apply bounded inward migration.
9. Disperse one epoch of unbound disk gas.
10. At every eighth epoch, merge bodies inside the formation Hill threshold.

No annulus is debited while the next embryo's claim is being calculated. That
rule prevents storage order from becoming hidden accretion priority.

An embryo's solid feeding zone is the larger of eight Hill radii and four
percent of its orbital radius. A tapered claim decreases toward the feeding-zone
edge. Every material component is transferred with the annulus mixture, and no
claim can make an inventory negative. The claim is a rate integrated over the
actual epoch duration, so a longer-lived otherwise identical disk can grow more
mass before dispersal.

## Primordial Gas and Migration

Gas capture derives a target envelope fraction from current solid mass and
elapsed megayears. Each epoch moves a duration-scaled fraction of the remaining
gap toward that target. Claims are distributed across local annuli and scaled
proportionally if several embryos request the same gas.

Migration is inward only. Its time-integrated fractional step depends on total
body mass, remaining global gas fraction, epoch duration, and policy efficiency,
with a hard three percent per-epoch cap. The disk inner edge supplies a `1.1`
multiplier trap.

After capture and migration, every annulus loses the exponential fraction for
that epoch's duration relative to the sampled disk lifetime. After the final
epoch, the generator disperses all gas still in the disk. Captured gas remains
on bodies until present-day escape; all other gas enters the dispersed ledger.

## Mergers and Final Architecture

The mutual Hill radius for adjacent bodies is:

```text
RH,m = ((m1 + m2) / (3 Mstar))^(1/3) * (a1 + a2) / 2
delta = (a2 - a1) / RH,m
```

Formation merges use `delta < 3.5`. Post-disk clearing repeatedly merges the
first semimajor-axis-ordered pair below:

- `12` mutual Hill radii for ordinary pairs
- `15` mutual Hill radii when either body is at least `30` Earth masses

The merged semimajor axis preserves the circular, star-dominated angular
momentum approximation:

```text
aMerged = ((m1 sqrt(a1) + m2 sqrt(a2)) / (m1 + m2))^2
```

All five composition masses add exactly. V1 models neither lost impact material
nor ejection.

Each final identity addresses its own random stream. Ordinary bodies receive a
Rayleigh eccentricity scale of `0.02`; giants and bodies with at least four
progenitors use `0.05`. Inclination uses a bounded normal draw. The resolver
then scales all eccentricities by `0.8` for at most 32 passes until adjacent
apoapsis-periapsis separation exceeds `3.5` mutual Hill radii. V1 persists the
formation-merger and radial-clearance multipliers separately even though both
initially equal `3.5`. Circular orbits are the deterministic final fallback.

The Hill filter is a conservative construction heuristic. It does not replace a
long-duration numerical integration.

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

``PlanetaryEnvironmentResolver`` integrates primordial-envelope escape over 48
logarithmic age intervals from `0.01` Gyr to the system age. Each interval uses
the star's stored present XUV fraction, a backward activity curve, incident
flux, current mass, and an updated radius to derive a binding proxy. Escape
subtracts only hydrogen and helium and records the removed mass in the gas
ledger.

The orbit-averaged bolometric flux is:

```text
S / SEarth = (L / LSun) / (a^2 sqrt(1 - e^2))
```

Radius begins with a solid mass power law modified by water and other volatiles.
Gas-bearing bodies receive an age-, mass-, flux-, and envelope-dependent
inflation proxy. Hydrogen-helium-dominated bodies above 30 Earth masses use a
separate bounded giant-radius branch.

Secondary atmosphere supply is a small fraction of accessible water and other
volatiles. Survival uses a smooth form of the empirical cosmic-shoreline trend:

```text
q = 4 log10(vescape / vescape,Earth) - log10(S / SEarth)
survival = logistic(3 (q + 0.25))
```

This is a population prior, not a deterministic law that small bodies cannot
have atmospheres. Cold or volatile-rich small bodies can retain tenuous output;
close, weakly bound bodies usually lose more.

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
the body's bulk mass.

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
```

The final hydrogen-helium invariant is:

```text
initial disk gas
  = retained planet and moon hydrogen-helium
  + escaped planetary hydrogen-helium
  + dispersed disk gas
```

Moon material appears exactly once. It is removed from the parent before both
bodies enter `retainedSolidMass`. The disk retains its initial solid composition,
and the ledger retains the unresolved annulus composition, so equal aggregate
solid mass cannot hide a component-transfer regression.

The ledger also records funded embryo count plus formation and post-disk merger
counts. V1 keeps leftover solids as unresolved material in the ledger; it does
not invent belt locations after formation.

## Validation and Failure

``GeneratedStarSystem/validate()`` rejects:

- a model version that differs from the stored policy
- a policy that is invalid or not the exact canonical calibration for its version
- star or disk facts that do not reproduce from the seed and canonical policy
- nonfinite, nonpositive, overflowing, or causally inconsistent physical values
- an invalid disk extent, component budget, lifetime, exponent, or annulus count
- duplicate, out-of-namespace, wrong-parent, or out-of-range body identities
- body, moon, progenitor, or merger counts outside their bounded ancestry ledger
- nonpositive body mass or radius
- a planetary periapsis inside the stellar radius
- planets not sorted by semimajor axis
- adjacent planets below required Hill spacing
- adjacent radial orbits without the required clearance
- a present radius, environment, or physical state that does not rederive from
  stored composition, orbit, star, and policy
- moon bounds that do not rederive from parent, moon, and orbital eccentricities
- a moon outside those bounds or an adjacent moon pair without Hill clearance
- a mismatch between resolved bodies, ancestry, and retained ledger values
- an open component-level solid or aggregate hydrogen-helium budget

Replayed floating facts and mass comparisons use a relative tolerance of `1e-9`
with a unit absolute scale floor. Planetary Hill checks allow `1e-10` additive
slack and moon radial checks allow one micrometer. Generation itself has finite
annulus, embryo, formation, evolution, eccentricity-damping, and moon-count
bounds. Moon repair strictly reduces count. The generator contains no unbounded
candidate retry for a more interesting system.

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

Direct unit coverage verifies:

- pinned SplitMix64 words
- three pinned canonical resolved-system fingerprints
- independent named random addresses
- unit-uniform bounds
- exact same-seed equality
- different-seed divergence
- Codable round trip followed by validation
- canonical policy admission, identity and ancestry integrity, and hostile
  decoded-value rejection
- stellar and disk calibration bounds and seed replay
- paired disk-lifetime, luminosity, distance, XUV, and gravity causality
- component-level solid and aggregate gas ledger closure
- semimajor-axis ordering and mutual-Hill separation
- both moon origins, eccentric Roche/Hill bounds, and moon-pair clearance
- the mean-flux equation
- final-albedo temperature consistency and opaque-boundary semantics
- all bulk, atmosphere, thermal, water, and visible-boundary regimes across a
  32-seed validated diversity smoke ensemble

The normal suite intentionally avoids observational occurrence-rate claims and
wall-time assertions. A future population-calibration executable should stream
statistics over tens or hundreds of thousands of seeds without retaining every
full system in memory.

## Future Integration

The next physical-model steps should be versioned additions or replacements,
not silent mutation of V1:

1. Replace analytic stellar proxies with bundled stellar and XUV tracks.
2. Calibrate ensemble distributions against observational datasets.
3. Add late scattering, ejections, debris, impacts, tides, and N-body audits.
4. Add richer interior, envelope, atmospheric chemistry, and climate tables.
5. Design authoritative celestial ECS state and a world builder that consumes
   an already resolved system.
6. Add gameplay projections over physical facts.
7. Add Render appearance descriptions and procedural surface inputs without
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
