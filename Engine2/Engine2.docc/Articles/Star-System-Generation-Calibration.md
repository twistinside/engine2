# Star System Generation Calibration

This article records the exact `coreAccretionLiteV1` calibration implemented by
``StarSystemGenerationPolicy`` and its phase collaborators. It separates sampled
priors, analytic physical approximations, population-tuning coefficients, and
numerical safety limits.

## Status

Implemented V1 reference.

The current in-place rewrite establishes the V1 compatibility baseline before
its first persistence freeze. After that freeze, changing any value, equation,
draw, ordering rule, or fallback in this article requires a new
``StarSystemGenerationModelVersion``. Correcting documentation to match unchanged
code does not require a new model version.

For ownership, workflow, output semantics, validation, and future integration,
see <doc:Star-System-Generation>.

## Reading Guide

- [Canonical Unit Definitions](#Canonical-Unit-Definitions),
  [Bounded Work](#Bounded-Work), and
  [Deterministic Random Addressing](#Deterministic-Random-Addressing) define the
  reproducibility contract.
- [Stellar Priors](#Stellar-Priors), [Disk Priors](#Disk-Priors), and
  [Disk Geometry and Normalization](#Disk-Geometry-and-Normalization) define the
  initial system.
- [Embryo Placement and Funding](#Embryo-Placement-and-Funding) through
  [Significant Moon Calibration](#Significant-Moon-Calibration) define formation.
- [Mean Stellar Flux](#Mean-Stellar-Flux) through
  [Derived Physical Thresholds](#Derived-Physical-Thresholds) define present facts.
- [Validation Tolerances](#Validation-Tolerances),
  [Expected Population Audits](#Expected-Population-Audits), and
  [Known V1 Biases](#Known-V1-Biases) define verification and limitations.

## Calibration Categories

| Category | Meaning |
| --- | --- |
| Unit definition | Fixed conversion used by a physical quantity type |
| Sampled prior | Distribution used to construct a synthetic population |
| Physical approximation | Reduced equation that preserves a causal relationship |
| Population calibration | Tunable coefficient chosen to produce useful physical variety |
| Numerical control | Bound, iteration count, clamp, tolerance, or fallback |
| Derived classification | Readable summary computed after all physical facts |

No population-calibration value is presented as a fundamental constant.

V1 bundles no external stellar track, survey catalog, or tabulated planetary
model. The references at the end provide scientific context; their data is not
copied into the target. A future table-backed model must record the exact source
release, selected fields, transformation script, generated artifact checksum,
and redistribution license beside the new model version.

## Canonical Unit Definitions

| Quantity | V1 definition | Category |
| --- | ---: | --- |
| Earth mass | `5.9722e24 kg` | Unit definition |
| Solar mass | `1.98847e30 kg` | Unit definition |
| Astronomical unit | `149,597,870,700 m` | Unit definition |
| Earth radius | `6,371,000 m` | Unit definition |
| Solar radius | `695,700,000 m` | Unit definition |
| Julian year | `31,557,600 s` | Unit definition |
| Solar luminosity | `3.828e26 W` | Unit definition |
| Bar | `100,000 Pa` | Unit definition |

Generated output serializes the canonical base-unit stored properties. Named
solar, Earth, AU, Myr, Gyr, kelvin, and bar values are computed projections.

## Bounded Work

| Control | V1 value | Category |
| --- | ---: | --- |
| Disk annuli | `128` | Numerical control |
| Candidate disk-structure attempts | `16` | Numerical control |
| Maximum embryos | `64` | Numerical control |
| Gas-disk epochs | `96` | Numerical control |
| Post-disk encounter attempts | `max(64, maximumEmbryoCount^2)` | Numerical control |
| Present-evolution epochs | `48` | Numerical control |
| Eccentricity damping passes | `32` | Numerical control |
| Climate iterations | `6` | Numerical control |
| Maximum significant moons per planet | `4` | Numerical control |
| Maximum resolved planets | `9` | Population calibration |

One system performs its floating-point reductions serially. Independent seeds
may be parallelized by an external population-audit caller, then ordered by
seed. V1 does not parallelize annuli or embryos within a system.

## Deterministic Random Addressing

Each stream starts with:

```text
key = rootSeed XOR domainRawValue
key = key + modelVersion * 0xD6E8FEB86659FD93
key = key XOR discriminator * 0xA0761D6478BD642F
state = mix(key)
```

All multiplication and addition in stream derivation and advancement wrap at
64 bits. SplitMix64 advancement adds:

```text
0x9E3779B97F4A7C15
```

The mixing function is:

```text
z = (z XOR (z >> 30)) * 0xBF58476D1CE4E5B9
z = (z XOR (z >> 27)) * 0x94D049BB133111EB
z = z XOR (z >> 31)
```

Named domain raw values are part of V1:

| Domain | Raw value |
| --- | --- |
| Star | `0x7A6A0D154A4F4D01` |
| Disk | `0x7A6A0D154A4F4D02` |
| Embryos | `0x7A6A0D154A4F4D03` |
| Formation | `0x7A6A0D154A4F4D04` |
| Orbital excitation | `0x7A6A0D154A4F4D05` |
| Moons | `0x7A6A0D154A4F4D06` |
| Dynamical clearing | `0x7A6A0D154A4F4D07` |
| Resolved planet multiplicity | `0x7A6A0D154A4F4D08` |

The formation domain supplies gas-disk collision-retention draws. Dynamical
clearing uses a separate stream addressed by the adjacent body identities and
encounter sequence, so one encounter cannot shift another phase's draws. The
resolved-planet-multiplicity domain samples output capacity independently of
formation and dynamical draws.

The first four star-domain words for seed `0x1234`, discriminator zero, and
model version one are pinned by tests:

```text
0x9EB357B585D20479
0xADB35A9C6DC83FA9
0x12999364D5A69B59
0x0D1E34BF8C1BC3F1
```

### Draw order

Distribution operations consume words in this order. A normal or log-normal
operation consumes the two uniforms used by Box-Muller. Integer rejection may
consume additional words, and a conditional operation consumes no word when its
branch is not taken.

| Domain | Operation order |
| --- | --- |
| Star | power-law mass; normal metallicity; uniform age; integer activity |
| Disk candidate | log-normal mass ratio; normal radius scatter; normal density exponent; repeat for each rejected candidate, up to 16 |
| Disk after structure admission | log-normal lifetime; normal iron fraction; dry-water unit draw; conditional wet-water uniform; normal solid-fraction scatter |
| Embryos | initial-radius uniform; one multiplicative-spacing uniform after each placement attempt |
| Formation collision | solid-retention uniform; hydrogen-helium-retention uniform |
| Dynamical encounter | outcome unit draw; conditional equal-mass ejection unit draw; conditional solid-retention uniform and hydrogen-helium-retention uniform for collision or failed scattering |
| Orbital excitation | per-body Rayleigh eccentricity; normal inclination |
| Resolved planet multiplicity | one bounded integer ticket for the capacity weights |
| Parent moon system | regular-moon integer count, or impact eligibility unit draw followed conditionally by impact-mass uniform; then one weight uniform per moon |
| Individual moon | Rayleigh eccentricity; normal inclination |

## Stellar Priors

| Quantity | V1 calibration | Category |
| --- | --- | --- |
| Stellar mass | Power law `M^-2.3`, truncated to `0.5...1.2 MSun` | Sampled prior |
| Metallicity | Normal `(-0.05, 0.20 dex)`, clamped to `-0.5...+0.5` | Sampled prior |
| Minimum age | `0.5 Gyr` | Sampled prior |
| Maximum age | `min(10 Gyr, 0.9 main-sequence lifetime)` | Physical approximation |
| Activity regime | Equal discrete probability: slow, median, fast | Sampled prior |

For power-law exponent `alpha = 2.3`, V1 inverse-samples between configured
bounds using the transformed exponent `1 - alpha`. Age is uniform between its
documented minimum and the mass-dependent maximum.

### Present stellar properties

With mass `M` in solar units and metallicity `Z = [Fe/H]`:

```text
Lnominal = M^3.8 * 10^(-0.12 Z)
tMainSequence = 10 Gyr * M / Lnominal
fAge = min(age / tMainSequence, 0.9)
Lcurrent = Lnominal * (0.7 + 0.65 fAge)
Rcurrent = M^0.8 * (0.87 + 0.28 fAge)
Teffective = 5772 K * (Lcurrent / Rcurrent^2)^0.25
```

Category: physical approximation and population calibration.

These are smooth analytic proxies, not MIST interpolation. Their purpose is to
make star mass, metallicity, and age affect system irradiation consistently.

### Activity

Activity multipliers are:

| Regime | Multiplier |
| --- | ---: |
| Slow | `0.5` |
| Median | `1.0` |
| Fast | `2.0` |

Present XUV-to-bolometric fraction is:

```text
fXUV = clamp(
    1e-3 * activityMultiplier * max(age / 0.1 Gyr, 1)^(-1.2),
    1e-7,
    1e-3
)
```

Category: physical approximation and population calibration.

The environment resolver consumes the stored present fraction directly. At
each logarithmic evolution interval it reconstructs the historic factor as:

```text
historicXUVFraction = min(
    1e-3,
    fXUV * max(intervalAge / finalAge, 0.002)^(-1.2)
)
```

The sampled activity regime therefore affects escape through `fXUV`; the
resolver does not maintain a second independent activity multiplier.

## Disk Priors

| Quantity | V1 calibration | Category |
| --- | --- | --- |
| Gas-to-star mass ratio | Base-10 log-normal, median `0.02`, scatter `0.5 dex` | Sampled prior |
| Gas-to-star clamp | `0.003...0.16` | Numerical control |
| Disk lifetime | Base-10 log-normal, median `3 Myr`, scatter `0.25 dex` | Sampled prior |
| Lifetime clamp | `1...10 Myr` | Numerical control |
| Characteristic radius | Correlated with sampled gas-disk mass to power `0.625`, with `0.25 dex` scatter | Sampled prior and physical approximation |
| Characteristic-radius clamp | `10...100 AU` | Numerical control |
| Surface-density exponent | Normal `(1.0, 0.2)`, clamped `0.5...1.5` | Sampled prior |
| Minimum annular Toomre `Q` | `1.4` | Physical admission bound |
| Base solid-to-gas fraction | `0.014` | Population calibration |
| Solid scatter | Normal `0.0, 0.1 dex` | Sampled prior |
| Solid-fraction clamp | `0.002...0.05` | Numerical control |
| Inner iron fraction | Normal `0.32, 0.05`, clamped `0.20...0.42` | Sampled prior |
| Inner water fraction | `45%` exactly zero; otherwise base-10 log-uniform `10^-4.5...10^-0.7` | Sampled prior |

The sampled solid fraction is:

```text
fSolid = clamp(
    0.014 * 10^([Fe/H] + normal(0, 0.1)),
    0.002,
    0.05
)
```

Metallicity controls the total condensed inventory. It does not directly set
the iron-to-silicate ratio; the independent iron fraction draw does.

For sampled gas-to-star ratio `fdisk`, stellar mass `Mstar` in solar units,
and one standard-normal radius draw `zR`:

```text
Rc = clamp(
    30 AU * ((fdisk Mstar) / 0.02)^0.625 * 10^(0.25 zR),
    10 AU,
    100 AU
)
```

Mass ratio, radius scatter, and surface-density exponent are sampled together.
The complete candidate is rejected when any represented annulus would have
`Q < 1.4`. V1 makes at most 16 attempts. If none passes, it combines the last
sampled radius scatter and exponent with the minimum ratio `0.003`; a
precondition keeps that canonical fallback inside the same stability bound.

## Disk Geometry and Normalization

The inner edge is:

```text
ainner = max(0.03 AU, 1.15 Rstar)
```

The outer edge is:

```text
aouter = max(4 ainner, min(150 AU, 5 Rc))
```

The fraction of the analytic tapered disk represented inside these edges is:

```text
k = 2 - p
frepresented = exp(-(ainner / Rc)^k) - exp(-(aouter / Rc)^k)
Mgas,represented = Mstar fdisk frepresented
Msolid,represented = Mgas,represented fSolid
```

The annulus edges are logarithmically spaced. For each annulus with geometric
center `a` and width `delta-a`:

```text
x = a / Rc
SigmaShape = x^(-p) exp(-x^(2 - p))
w = 2 pi a delta-a SigmaShape
```

Every weight is divided by the sum of all 128 weights. Gas and solid masses use
the same normalized radial weights. Stored initial gas and solid masses are the
represented reservoirs, not the unbounded analytic disk mass. Category:
physical approximation plus numerical normalization.

### Gravitational-stability admission

For each annulus center `a`, V1 estimates:

```text
T = max(10 K, 280 K * Lstar^0.25 / sqrt(a / AU))
cs = sqrt(kB T / (2.34 mp))
Omega = sqrt(G Mstar / a^3)
Sigmaunit = Mstar * fannulus / (pi (router^2 - rinner^2))
Qunit = cs Omega / (pi G Sigmaunit)
fdisk,maximum = minAnnuli(Qunit) / 1.4
```

`fannulus` includes the analytic represented-mass fraction. A candidate passes
when its sampled `fdisk` does not exceed `fdisk,maximum`. This is a local
thin-disk stability proxy, not a hydrodynamic fragmentation calculation.

## Formation Luminosity and Snow Line

V1 formation luminosity is:

```text
Lformation = max(Lcurrent, 1.5 Mstar^2)
```

The water snow-line radius is:

```text
asnow = 2.7 sqrt(Lformation) AU
```

Category: physical approximation and population calibration.

This proxy stands in for pre-main-sequence luminosity plus viscous disk heating.
It is not a solved disk-temperature field.

## Condensed Composition

The snow-line transition coordinate is:

```text
t = clamp(((a / asnow) - 0.8) / 0.4, 0, 1)
```

Endpoint mixtures are:

| Component | Inner endpoint | Outer endpoint |
| --- | ---: | ---: |
| Iron | sampled near `0.32` | `0.10` |
| Silicate | `1 - inner iron` | `0.25` |
| Water | sampled inner water fraction | `0.55` |
| Other volatiles | `0` | `0.10` |

Every component interpolates linearly by `t`, then all four fractions are
renormalized to one. Category: population calibration.

The dry branch consumes only its branch draw. The non-dry branch consumes one
additional uniform draw for the logarithmic water fraction. This conditional
draw order is part of deterministic V1 output. Trace inner water is a coarse
proxy for heterogeneous local hydration and later volatile delivery; V1 does
not separately record those mechanisms.

The model does not yet include separate refractory, CO2, ammonia, methane, CO,
or nitrogen condensation fronts.

## Embryo Placement and Funding

| Quantity | V1 value | Category |
| --- | ---: | --- |
| First radius multiplier | Uniform `1.25...1.45` times inner edge | Sampled prior |
| Successive radius multiplier | Uniform `1.16...1.28` | Sampled prior |
| Seed target mass | `0.01 Earth masses` | Population calibration |
| Funding neighborhood | nearest annulus plus two on each side | Numerical control |
| Maximum placement radius | `min(40 AU, disk outer edge)` | Numerical control |

For one placement, V1 sums available solids in the five-annulus neighborhood.
It withdraws the complete target only when the neighborhood can supply it:

```text
availableSolid < seedTarget: no withdrawal and no embryo
availableSolid >= seedTarget: fwithdraw = seedTarget / availableSolid
```

The successful branch applies `fwithdraw` to every neighborhood annulus. This
preserves the local aggregate mixture and makes every created embryo exactly
the configured seed mass. Identity is `fundedEmbryoIndex + 1`. Unfunded
placements do not consume an identity.

After each placement attempt, the radial step is the larger of the sampled
geometric step and the seed-mass Hill step:

```text
delta-ageometric = a (uniform(1.16, 1.28) - 1)
RHill,seed = a (2 Mseed / (3 Mstar))^(1/3)
delta-aHill = max(8, 2 formationMergerSpacing) RHill,seed
delta-a = max(delta-ageometric, delta-aHill)
```

With canonical `formationMergerSpacing = 3.5`, the Hill multiplier is eight.
The maximum of 64 funded embryos still bounds placement.

## Feeding Zones and Solid Claims

For embryo mass `m`, stellar mass `Mstar`, and semimajor axis `a`:

```text
RHill = a (m / (3 Mstar))^(1/3)
feedingHalfWidth = max(8 RHill, 0.04 a)
```

For disk-lifetime epoch duration `delta-t` in Myr, the untapered solid claim is:

```text
rateSolid = 30 / Myr
          * solidAccretionEfficiency
          * max(Msolid, 1e-6)^(2/3)
          * max(a, 0.03)^(-1/2)

fbase = min(0.25, 1 - exp(-rateSolid delta-t))
```

`solidAccretionEfficiency` is `0.45`.

For annulus-center distance `d` inside the feeding zone:

```text
taper = max(0, 1 - d / max(feedingHalfWidth, annulusWidth))
claim = fbase * (0.25 + 0.75 taper)
```

Category: population calibration and numerical control.

For each annulus, if the sum of claims is `C`, each claim is multiplied by
`min(1, 1/C)`. The annulus loses `min(C, 1)` of every solid component. This is
the exact order-independence and conservation rule.

## Primordial Envelope Demand and Supply

Only a core with `Mcore >= 0.3 Earth masses` requests gas. At elapsed disk time
`T` and epoch duration `delta-t`, both in Myr:

```text
fsupported = min(1, 0.0025 Mcore^1.7 sqrt(max(T, 1e-6)))
Msupported = Mcore fsupported
tKH = max(0.01, 4 (Mcore / 5)^(-3))
fcooling = 1 - exp(-gasAccretionEfficiency delta-t / tKH)
Mattached = max(0, Msupported - Mcurrent) fcooling
```

When `Mcurrent >= 0.45 Mcore`, runaway demand is also eligible:

```text
xrunaway = min(3, gasAccretionEfficiency delta-t / tKH)
Mrunaway = max(Mcurrent, 0.01 Mcore) expm1(xrunaway)
McoolingDemand = max(Mattached, Mrunaway)
```

Otherwise `McoolingDemand = Mattached`. `gasAccretionEfficiency` is `0.60`.

The local capture half-width is:

```text
delta-acapture = max(0.75 RHill, 0.01 a)
```

For body-star mass ratio `q`, disk aspect ratio `h`, and turbulent-viscosity
proxy `alpha = 0.002`:

```text
h = clamp(
    0.033 max(Lstar, 1e-6)^0.125 max(a, 0.03)^0.25 / sqrt(Mstar),
    0.025,
    0.12
)
q = max(Mtotal / Mstar, 1e-12)
K = q^2 / (alpha h^5)
gapDepth = 1 / (1 + 0.04 K)
fgapFlow = max(0.02, sqrt(gapDepth))
```

The local hydrodynamic and viscous supply caps are:

```text
Mhydro = MlocalGas
       * (1 - exp(-3 gasAccretionEfficiency
           * (max(Mtotal, 0.1) / 10)^(2/3)
           * delta-t))
       * fgapFlow

tvisc = max(0.05, 0.35 (max(a, 0.03) / 5)^0.75 / sqrt(Mstar))
Mvisc = MlocalGas (1 - exp(-delta-t / tvisc)) fgapFlow

Mrequested = min(McoolingDemand, Mhydro, Mvisc)
```

Masses use Earth units, radii use AU, and times use Myr in these calibration
equations. Requested gas is distributed across overlapping local annuli in
proportion to current gas. Contested requests scale by
`min(1, available/requested)`. Category: physical approximation, population
calibration, and numerical control.

## Migration and Disk Dispersal

Local gas availability uses the nearest annulus:

```text
flocalGas = nearestAnnulusRemainingGas / nearestAnnulusInitialGas
```

For epoch duration `delta-t` in Myr, the unsuppressed type-I rate is:

```text
rateTypeI = 0.384 / Myr
          * migrationEfficiency
          * Mtotal / (1 + Mtotal / 30)
          * flocalGas
```

`migrationEfficiency` is `0.18`. Gap opening uses:

```text
Pgap = 0.75 h a / RHill + 50 alpha h^2 / q
```

When `Pgap > 1`, the body uses `rateTypeI` and moves toward the nearer attractor
in log radius:

```text
ainnerTrap = max(1.8 ainner, 0.18 asnow)
attractor = nearestInLogRadius(ainnerTrap, asnow)
```

This branch can move inward or outward. When `Pgap <= 1`, the rate and attractor
are:

```text
rateGap = min(rateTypeI * max(0.03, gapDepth), 1 / tvisc)
attractor = min(a, ainnerTrap)
```

The applied fractional step is `min(0.03, 1 - exp(-rate delta-t))` and stops at
the selected attractor. Category: physical approximation, population
calibration, and numerical control.

Each epoch then multiplies all unbound gas by:

```text
exp(-3 delta-t / tdisk)
```

The removed difference enters dispersed gas. After the final epoch, all
remaining annulus gas also enters dispersed gas. Category: physical
approximation.

## Gas-Disk Collisions

Every eighth epoch, and once after the last epoch, adjacent bodies with fewer
than `3.5` mutual Hill radii collide. This is the persisted
`formationMergerSpacing` calibration. The array sorts by semimajor axis, then
stable identity. The first failing pair collides and the scan restarts.

Identity and progenitor rules are:

```text
remnantID = min(firstID, secondID)
remnantProgenitorCount = firstCount + secondCount
```

The collision samples one common retention factor for every solid component
and a separate hydrogen-helium factor:

```text
fsolidRetained = uniform(0.985, 1)
fgasRetained = uniform(0.55, 0.90)
```

The remnant receives each combined component times its retention factor. The
remainder is explicit collision debris. Stripped solids return to the nearest
disk annulus. They remain eligible for accretion when formation epochs remain;
solids returned by the final collision pass remain unaccreted. Stripped
hydrogen-helium enters dispersed gas. The remnant semimajor axis is:

```text
aRemnant = ((m1 sqrt(a1) + m2 sqrt(a2)) / (m1 + m2))^2
```

Category: physical approximation, population calibration, deterministic
tie-break, and explicit conservation routing.

## Post-Disk Encounters and Final Architecture

Required mutual-Hill spacing is:

| Pair | Required spacing |
| --- | ---: |
| Both below `30 Earth masses` | `12` |
| Either at least `30 Earth masses` | `15` |

Category: population calibration and conservative construction filter.

The ordinary value is motivated by the clustering Pu and Wu report for compact
Kepler systems. The giant value is an additional Engine2 margin, not a threshold
from that study.

The first adjacent pair below its required spacing enters an encounter. With
current spacing `delta`, required spacing `deltaRequired`, estimated formation
radii `R1` and `R2`, and mean semimajor axis `amean`:

```text
Rcore = max(Msolid, 1e-6)^0.27 Earth radii

Restimated = Rcore                                      when fenv <= 1e-6
Restimated = min(12, max(Rcore, 8 + 4 min(fenv, 1)))   when Mtotal >= 50 or fenv >= 0.5
Restimated = Rcore (1 + min(2.5, 4 sqrt(fenv)))        otherwise
```

The encounter converts these radii to AU before evaluating `x`:

```text
s = clamp((deltaRequired - delta) / deltaRequired, 0, 1)
x = 2 ((M1 + M2) / Mstar) amean / (R1 + R2)
proximity = min(1, 0.1 / max(ainner, 0.01))

pstar = min(0.12, 0.015 + 0.08 s proximity)
pejectGivenSurvival = min(0.72, max(0, (x - 0.8) / 4) s)
pcollisionGivenRemaining = min(0.55, 0.18 + 0.38 / (1 + x))
```

One unit-uniform draw selects the outcome with conditional thresholds:

```text
tstar = pstar
teject = tstar + (1 - tstar) pejectGivenSurvival
tcollision = teject + (1 - teject) pcollisionGivenRemaining

u < tstar:       inner body accretes onto the star
u < teject:      one body is ejected
u < tcollision:  the pair collides
otherwise:       attempt scattering
```

The ejection branch removes the lower-mass body. An exact mass tie consumes one
additional unit draw. Ejected and star-accreted composition and ancestry remain
separate ledger destinations.

Post-disk collision retention depends on encounter severity:

```text
fsolidRetained = max(0.90, 0.995 - 0.08 s uniform(0.5, 1))
fgasRetained = max(0.15, 0.80 - 0.60 s uniform(0.5, 1))
```

The stripped composition enters the collision-debris ledger and is not returned
to an annulus after disk dispersal.

Scattering preserves `M1 sqrt(a1) + M2 sqrt(a2)` while trying separation
expansions `1`, `1.25`, `1.5`, and `2`. Its target separation is `1.05` times
the required spacing times the pair's current mutual Hill radius. Candidate
orbits must stay above `1.001` times the disk inner edge and below `0.999` times
the disk outer edge. A failed scatter becomes a collision.

Successful scattering resets both pair eccentricities to zero. The loop
attempts at most `max(64, maximumEmbryoCount^2)` encounters. If close pairs
remain, the bounded fallback ejects the smaller body from each pair until the
Hill-spacing requirement passes; an exact mass tie ejects the inner body. These
are population approximations, not phase-resolved orbital dynamics.

Final orbital excitation is:

| Body | Eccentricity Rayleigh scale |
| --- | ---: |
| Ordinary | `0.02` |
| At least four progenitors or at least `30 Earth masses` | `0.05` |

Eccentricity clamps to `0.18`. Inclination is the absolute value of a zero-mean
normal with `0.8` degree standard deviation, clamped to `5` degrees.

Adjacent radial clearance must satisfy:

```text
aouter (1 - eouter) - ainner (1 + einner) >= 3.5 RHill,mutual
```

The multiplier is the separately persisted `radialClearanceHillRadii`
calibration. V1 initializes both spacing values to `3.5`, but changing one does
not silently change the other.

All eccentricities multiply by `0.8` together until the requirement passes or
32 attempts complete. The final fallback sets every eccentricity to zero.

## Resolved-Planet Multiplicity and Eligibility

After dynamical clearing, V1 samples one `resolvedPlanetCapacity` in `0...9`.
The sample uses a uniformly selected ticket across these integer weights:

```text
capacity  0  1  2  3  4  5  6  7  8  9
weight    5  9 12 14 15 15 14 12  9  5
```

The sampler draws one integer ticket from `0...109` and maps it through the
cumulative weights. The symmetric weights form a beta-binomial-shaped capacity
distribution. This is output/population calibration, not a claim that formation
obeys a physical nine-body limit. Formation can leave more survivors. The
ledger persists the sample so decoded output retains the choice that bounded
its resolved planets.

A survivor is eligible for resolved output when its pre-moon solid mass is at
least `0.10 Earth masses`. This threshold is ten times the solid-only
`0.01`-Earth-mass seed. Selection sorts eligible survivors by descending
pre-moon solid mass, breaks an exact tie by smaller stable identity, and takes
at most `resolvedPlanetCapacity` values. Zero is a valid capacity, and V1 does
not force a fallback planet when the capacity is zero or no survivor is
eligible.

```text
resolvedPlanetCount = min(resolvedPlanetCapacity, eligibleSurvivorCount)
```

Every omitted survivor contributes its full composition, body count, and
progenitor count to the residual-body fields in ``StarSystemFormationLedger``.
The residual aggregate therefore includes both subthreshold survivors and
eligible survivors beyond the sampled capacity. It receives no individually
resolved radius, orbit, environment, moons, or classification. The aggregate is
not a resolved belt or spatial distribution. Category: output/population
calibration and explicit conservation routing.

## Significant Moon Calibration

### Eligibility

Before extracting material, the parent must have a conservative available
region at the maximum V1 moon eccentricity `emoon = 0.04`:

```text
Rsolid = max(0.03, Msolid^0.27 * (1 + 0.25 fwater)) Earth radii
Rparent,conservative = max(Rsolid, 14) when fHHe >= 0.5
Rparent,conservative = max(Rsolid, 10) when 1e-5 < fHHe < 0.5
Rparent,conservative = Rsolid otherwise
```

```text
fcritical = max(
    0.05,
    0.4895 * (1 - 1.0305 eplanet - 0.2738 emoon)
)

fcritical RHill,parent > 6 Rparent,conservative / (1 - emoon)
```

Conservative radius is:

- solid-radius proxy for effectively airless bodies
- at least `10 Earth radii` for any small primordial envelope
- at least `14 Earth radii` for a body at least half hydrogen-helium

Category: numerical control.

### Regular moons

Eligibility requires:

- total mass at least `10 Earth masses`
- hydrogen-helium fraction at least `0.10`

Count is uniform from one through four, clamped by policy. Combined mass is:

```text
min(0.02 MparentSolids, 2e-4 MparentTotal)
```

Category: population calibration.

### Giant-impact moons

Eligibility requires:

- more than one progenitor
- total mass at least `0.1 Earth masses`
- unit-uniform draw below `0.40`

One moon receives a uniform `0.002...0.015` fraction of parent solid mass.
Category: population calibration.

### Partition and placement

For multiple moons, raw weights are uniform `0.5...1.5` and normalized to one.
The total extracted fraction clamps to at most five percent of parent solids.

Planet identities occupy the positive low 40-bit range. Satellite identities
use bit 63 as the moon namespace, the parent identity in bits `16...55`, and a
one-based ordinal in bits `0...15`; reserved bits `56...62` remain zero. The
placement fractions for `n` moons are
`1 / (n + 1)` through `n / (n + 1)`.

After the moon's radius and eccentricity have been resolved, the lower bound is:

```text
minimumRadialDistance = Rparent * max(
    6,
    1.05 * 2.44 * (rhoParent / rhoMoon)^(1/3)
)
amin = minimumRadialDistance / (1 - emoon)
```

The upper bound is:

```text
fcritical = max(
    0.05,
    0.4895 * (1 - 1.0305 eplanet - 0.2738 emoon)
)
amax = fcritical RHill,parent
```

Placement interpolates in log distance between the bounds. Moon eccentricity
uses Rayleigh scale `0.005`, clamped to `0.04`. Inclination is the absolute value
of a one-degree normal, clamped to `10` degrees.

After placement, the moons sort by semimajor axis. For each adjacent pair:

```text
outerPeriapsis - innerApoapsis >= 3.5 RHill,mutual
```

V1 merges the first failing pair by adding composition, retaining the smaller
identity, and mass-weighting its normalized placement coordinate. It then
resolves and checks the reduced moon set again. Every pass reduces the count,
so repair is bounded by the original maximum of four moons. Category: physical
approximation, deterministic tie-break, and numerical control.

## Mean Stellar Flux

For luminosity in solar units, semimajor axis in AU, and bound eccentricity:

```text
Smean / SEarth = L / (a^2 sqrt(1 - e^2))
```

Category: physical approximation for orbit-averaged irradiation.

V1 does not store or sample periapsis and apoapsis flux separately. They can be
derived from the stored luminosity and orbit when a later consumer needs them.

## Primordial Envelope Escape

The resolver first applies boil-off and core-powered budgets. With initial
visible radius evaluated at `0.01 Gyr` and a first-pass equilibrium temperature
using albedo `0.30`:

```text
Teq,initial = 278.5 K * max(0.7 S, 0)^0.25
RBondi = G M (2.3 mp) / (kB max(Teq,initial, 30 K))
Rcontracted = 0.1 RBondi

funbound = min(0.9, 1 - Rcontracted / Rinitial) when Rinitial > Rcontracted
funbound = 0 otherwise
MafterBoilOff = Mgas,initial (1 - funbound)
```

The core-powered vulnerable ratio is:

```text
fvulnerable = min(
    0.05,
    0.015
        * max(Teq,initial / 1000 K, 0.05)^1.5
        * max(Mcore / 5, 0.002)^(-0.5)
)

MafterCorePower = max(0, MafterBoilOff - Mcore fvulnerable)
```

The surviving envelope then enters 48 logarithmic energy-limited intervals
from `0.01 Gyr` to the sampled system age.

At midpoint age `t`, the stored present XUV fraction drives historic exposure:

```text
fXUV,historic = min(
    1e-3,
    fXUV,present * max(t / finalAge, 0.002)^(-1.2)
)
```

With current total mass `M`, resolved radius `R`, mean bolometric flux relative
to Earth `S`, and interval duration `delta-t`, V1 evaluates the absolute
energy-limited capacity in SI units:

```text
FXUV = 1361 W/m^2 * max(S, 0) * fXUV,historic
delta-Mcapacity = atmosphereEscapeEfficiency
                    * pi R^3 FXUV delta-t
                    / (G M)
Mgas,new = max(0, Mgas,old - delta-Mcapacity)
```

`atmosphereEscapeEfficiency` is `0.10`.

Category: physical approximation and population calibration.

Each phase subtracts a finite absolute mass budget and can produce exactly zero.
The implementation does not apply a trace-mass cutoff. A nonfinite
energy-limited capacity strips the remaining envelope rather than retaining an
invalid mass. The relation omits Roche enhancement, composition-dependent
heating, hydrodynamic chemistry, and interior cooling solutions.

## Radius Approximation

For solid mass `Msolid`, water fraction `fwater`, and other-volatile fraction
`fother`:

```text
Rsolid = max(Msolid, 1e-8)^0.27 * (1 + 0.25 fwater + 0.10 fother)
```

Minimum solid radius is `0.03 Earth radii`.

For an envelope fraction above `1e-5` but outside the giant branch:

```text
delta-R = 2.2
        * max(fenv / 0.05, 1e-4)^0.25
        * max(Mtotal / 5, 0.1)^(-0.10)
        * max(S, 0.01)^0.04
        * max(age / 5 Gyr, 0.02)^(-0.08)

R = max(Rsolid, min(10, Rsolid + delta-R))
```

If envelope fraction is at least `0.5` and mass is at least `30 Earth masses`:

```text
R = max(Rsolid, clamp(10.5 + 0.6 log10(max(M / 100, 0.1)), 8, 14))
```

Both branches preserve `R >= Rsolid`; a visible atmospheric boundary never
falls inside the modeled solid body.

Category: physical approximation and population calibration.

These are not interior solutions. Lopez and Fortney motivate the dependency of
sub-Neptune radius on envelope fraction, mass, irradiation, and age, but the V1
coefficients are Engine2's bounded interpolation.

## Secondary Atmosphere

Escape velocity relative to Earth is approximated by:

```text
vescapeRelative = sqrt(max(M / Rsolid, 1e-8))
```

The shoreline and supply terms are:

```text
q = 4 log10(max(vescapeRelative, 1e-5))
  - log10(max(S, 1e-6))

geologicSupply = M / (M + 0.3)
accessibleVolatiles = Mwater + MotherVolatiles
Msupplied = accessibleVolatiles * 0.0001 * geologicSupply

MsecondaryAtmosphere = Msupplied when q >= -0.25
MsecondaryAtmosphere = 0 otherwise
```

Category: physical approximation and population calibration.

The fourth-power shoreline trend comes from Zahnle and Catling. The hard
`-0.25` boundary, supply fraction, and geologic term are V1 calibrations. The
erosive side loses the complete supplied phase; V1 does not manufacture a
positive trace with a sigmoid tail.

Total atmosphere phase mass is:

```text
Matmosphere = MretainedHydrogenHelium + MsecondaryAtmosphere
```

No component mass is added. The secondary phase remains part of the stored water
and other-volatile inventories.

## Pressure and the Visible Boundary

V1 uses modern Earth atmosphere mass `8.62e-7 Earth masses` as its one-bar
normalization. It first estimates pressure at the exposed solid radius:

```text
Pexposed = (Matmosphere / 8.62e-7)
         * Mtotal
         / max(Rsolid^4, 1e-8)
```

Category: physical approximation.

The fourth radius power combines surface gravity's `M/R^2` dependency with
atmosphere column area `R^2`.

V1 marks the visible boundary opaque when either condition holds:

```text
MhydrogenHelium / Mtotal >= 0.01
Pexposed >= 100 bar
```

An opaque body publishes no ``PlanetaryEnvironment/surfacePressure`` because V1
does not claim access to a solid boundary beneath the envelope. Its climate
proxy instead evaluates the visible column with the envelope-inflated radius:

```text
Pvisible = (Matmosphere / 8.62e-7)
         * Mtotal
         / max(Rvisible^4, 1e-8)
```

An exposed body publishes `Pexposed` and uses that same value in climate.

## Climate Iteration

The first albedo is `0.30`. Six iterations apply:

```text
Tequilibrium = 278.5 K * max(S (1 - A), 0)^0.25
Tboundary = Tequilibrium * (1 + 0.75 tau)^0.25
```

Optical depth is based on the selected exposed or visible-column pressure:

```text
deep envelope: min(60, 2 + 6 log1p(Pbar))
other:         min(20, 0.7 sqrt(Pbar))
```

The next albedo is:

| Condition | Albedo |
| --- | ---: |
| Deep envelope below `180 K` | `0.55` |
| Other deep envelope | `0.35` |
| Solid water fraction above `1e-4` and below `260 K` | `0.60` |
| Solid water fraction above `1e-4` and below `360 K` | `0.30` |
| Above `900 K` | `0.12` |
| Other exposed body | `0.22` |

Category: population calibration and bounded numerical iteration.

After the sixth albedo update, V1 recomputes equilibrium and visible-boundary
temperature once with the stored final albedo. The returned temperature and
albedo therefore describe the same iteration state.

## Water Coverage

Opaque bodies publish zero liquid and ice coverage because their solid water is
inaccessible to this climate model. For an exposed body, water below a `1e-5`
solid mass fraction is treated as dry. Otherwise:

```text
availableCoverage = min(1, 2500 fwater)
```

| Condition | Liquid coverage | Ice coverage |
| --- | ---: | ---: |
| `T < 260 K` | `0` | `availableCoverage` |
| `273...373 K` and `P >= 0.006 bar` | `availableCoverage` | `0.05 * (1 - availableCoverage)` |
| Other | `0` | `0` |

Category: population calibration.

This is a regime mapper, not a phase-diagram solver. Water classification uses
`inaccessible` for opaque boundaries and `steam` above `373 K` for exposed
bodies. Otherwise it derives global ocean, partial liquid, or ice only from the
corresponding positive coverage. A water-bearing body with no modeled stable
surface coverage is dry.

## Derived Physical Thresholds

### Bulk

The first matching rule wins:

1. Hydrogen-helium fraction at least `0.5`: hydrogen-helium dominated.
2. Solid water plus other-volatiles fraction at least `0.25`: volatile rich.
3. Solid iron fraction at least `0.38`: metal rich.
4. Otherwise: rocky.

### Atmosphere

| Condition | Regime |
| --- | --- |
| Surface pressure is absent because the boundary is opaque | Deep envelope |
| Exposed surface pressure at least `0.05 bar` | Secondary |
| Exposed atmosphere mass is greater than zero and pressure is below `0.05 bar` | Tenuous |
| Atmosphere mass is exactly zero | Airless |

Deep envelopes produce an opaque visible boundary. All other atmosphere regimes
produce an exposed-solid boundary in V1. There is no trace-pressure cutoff:
complete primordial and secondary loss remains exact zero, while every positive
resolved atmosphere mass is at least tenuous.

### Thermal

| Boundary temperature | Regime |
| --- | --- |
| Below `240 K` | Frozen |
| `240...350 K` | Temperate |
| Above `350 K` and below `1,200 K` | Hot |
| At least `1,200 K` | Molten |

### Water

The first matching rule wins:

1. Opaque boundary: inaccessible.
2. Water fraction below `1e-5`: dry.
3. Boundary temperature above `373 K`: steam.
4. Liquid coverage at least `0.80`: global ocean.
5. Positive liquid coverage: partial liquid.
6. Positive ice coverage: ice covered.
7. Otherwise: dry because no stable surface water is modeled.

All thresholds in this section are derived-classification calibration. They do
not change component masses or environment values.

## Validation Tolerances

Mass closure and numeric replay of derived persisted facts use:

```text
require first and second to be finite
scale = max(abs(first), abs(second), 1)
valid = abs(first - second) <= scale * 1e-9
```

Planetary Hill-spacing and radial-clearance comparisons allow `1e-10` additive
numeric slack. Moon orbit-bound and pair-clearance comparisons allow `1e-6 m`
additive slack. Enum values, optionality, identity namespaces, counts, ancestry,
and ordering remain exact. Category: numerical control.

Validation also reconciles retained, residual, ejected, star-accreted, and
collision-debris body and progenitor counts with the funded embryo count. It
requires a zero residual composition exactly when both residual counts are
zero. For positive capacity, it also applies one necessary aggregate selection
bound:

```text
boundary = minimumResolvedPlanetSolidMassEarth
    when resolvedPlanetCount < resolvedPlanetCapacity

boundary = minimum resolved parent-plus-moons solid mass
    when resolvedPlanetCount == resolvedPlanetCapacity

MresidualSolids <= boundary * residualBodyCount * (1 + 1e-9)
```

When capacity is zero, the residual aggregate has no resolved selection
boundary because every survivor is intentionally omitted.

Validation includes residual and dynamical compositions in every mass closure.
It replays `resolvedPlanetCapacity` from the root seed through the
`resolvedPlanetMultiplicity` domain, rejects a value outside
`0...maximumResolvedPlanetCount`, and rejects more published planets than the
capacity permits. Selection compares each pre-moon embryo's solid mass with
`minimumResolvedPlanetSolidMassEarth`. Moon extraction later partitions parent
solids without changing the parent-plus-moons total, so validation requires
every published parent-plus-moons system to meet that threshold. Validation
uses the aggregate boundary above as a necessary ranking check, but does not
replay formation to prove that each decoded planet was among the highest
eligible survivors.

The normal regression policy pins the first random words and three canonical
resolved-system fingerprints. Focused tests cover same-seed equality,
serialization, corruption rejection, conservation, stellar and disk bounds,
Toomre admission through the shared disk profile, the fully funded seed-mass
floor, orbit and moon stability, causal environment trends, both moon origins,
and the exact-zero atmosphere boundary. A bounded representative-seed smoke
ensemble checks finite validation plus regime, capacity, and resolved-count
reachability. These are regression contracts, not occurrence-rate calibration.

Fingerprint updates require a reviewed model change plus passing focused
invariants; observing a new hash is not sufficient approval. The in-place V1
rewrite establishes a new baseline before the compatibility freeze. Later
behavioral changes require a new model version instead of replacing V1 hashes.

## Expected Population Audits

Ordinary unit tests prove causal and invariant behavior. Calibration requires a
separate large-seed audit whose artifact identifies the model version, complete
policy, seed interval, supported Swift toolchain, and execution platform. It
records, at minimum:

- generated failure count and reason
- sampled resolved-planet capacity, actual resolved-planet count, and
  significant-moon count distributions
- stellar mass, metallicity, age, and luminosity distributions
- disk gas, solid, radius, lifetime, mass-radius correlation, admission-attempt,
  and minimum-Toomre-`Q` distributions
- retained, unaccreted-annulus, residual-body, ejected, star-accreted,
  collision-debris, escaped, and dispersed mass fractions
- planet mass, radius, semimajor axis, eccentricity, and composition quantiles
- formation collision, post-disk collision, scattering, ejection, stellar-loss,
  residual-body, and residual-progenitor counts
- primordial-envelope occurrence by mass and flux
- exact-zero atmosphere occurrence by body mass and flux
- physical-state cross-tabulations
- minimum final Hill spacing
- conservation residual maxima
- generation operation time and peak memory

Occurrence-rate targets and acceptable deltas must live in an audit
specification beside the model version. The audit should stream aggregates
rather than retain every system. Do not add tight noisy population percentages
or wall-time assertions to the normal unit suite.

## Observed 1,000-Seed Baseline

The sampled-capacity V1 calibration was measured on August 11, 2026, with seeds
`0..<1,000` in ascending serial order. A standalone Swift 6.4 executable
compiled the production generator with `-O` and whole-module optimization on an
Apple M4 Mac mini with 16 GB of memory running macOS 27.0. Compilation was
outside the measured interval. Each sample called `generate(seed:)` once; that
operation includes the generator's normal validation pass.

Performance:

- `1,000` successes and `0` failures
- `6.987` seconds of measured generator work, or `143.1` systems per second
- per-system latency: `6.985 ms` mean, `7.083 ms` median, `8.230 ms` p95,
  `8.691 ms` p99, and `13.273 ms` maximum
- `9,895,936` bytes maximum resident set size, or `9.44 MiB`

Sampled capacity histogram:

```text
capacity   0   1    2    3    4    5    6    7   8   9
systems   39  72  103  138  150  143  119  117  74  45
```

Resolved-planet histogram:

```text
planets    0   1    2    3    4    5    6    7   8   9
systems   51  72  106  141  147  149  114  108  70  42
```

The mean sampled capacity was `4.537`. The mean resolved count was `4.418`, the
median was `4`, p95 was `8`, and all values were inside `0...9`. Residual formed
bodies had mean count `23.074`, median `24`, p95 `32`, and maximum `36`; they
remain conserved aggregate provenance rather than resolved planets.

Resolved architecture and mass tail:

- `4,418` resolved planets and `1,574` significant moons
- planet mass: `2.766 Earth masses` median, `386.076 Earth masses` p99, and
  `1,182.037 Earth masses` maximum, approximately `3.72 Jupiter masses`
- `60` Jupiter-mass-or-larger planets and no body at or above `13 Jupiter`
  masses
- `2,925` post-disk collisions, `6,037` scattering resolutions, `2,103`
  ejected bodies, and `178` star-accreted bodies

Present atmosphere states included `228` airless, `71` tenuous, `1,903`
secondary-atmosphere, and `2,216` deep-envelope planets. Every airless planet
stored exactly zero atmosphere mass. Water states included `171` dry, `1,949`
ice-covered, `6` partial-liquid, `23` global-ocean, `53` steam, and `2,216`
inaccessible planets.

This cohort is a deterministic implementation and outlier baseline. It is not
an observational occurrence-rate fit, a complete population-audit artifact, or
a timing assertion for CI.

An additional Release endurance check generated seeds `0..<10,000` plus `257`
`UInt64` boundary and bit-pattern seeds. It completed `10,257` generations with
zero failures. The check repeated generation and performed a canonical
encode-decode-validate round trip for `1,257` systems with zero mismatches or
validation failures. The sequential cohort produced this resolved-count
histogram:

```text
planets     0    1     2     3     4     5     6     7    8    9
systems   548  792  1099  1334  1398  1378  1210  1069  770  402
```

Its mean was `4.3995`, its median was `4`, and its maximum was `9`. Generation
ran at `141.3` systems per second with `12,025,856` bytes maximum resident set
size. The check also observed positive final Hill and radial-clearance margins,
exact-zero atmosphere mass for every airless planet, and no zero-atmosphere
planet classified as non-airless. This is a deterministic endurance check, not
an observational occurrence-rate calibration.

## Known V1 Biases

V1 is expected to bias output in these ways:

- A narrow stellar-mass range omits abundant lower-mass red dwarfs and all
  higher-mass main-sequence stars.
- Smooth stellar proxies omit track structure and pre-main-sequence duration.
- The analytic mass-radius correlation and Toomre admission filter can distort
  the sampled disk priors; neither replaces a viscous, self-gravitating disk.
- Identical gas and solid surface-density weights omit radial drift and local
  dust evolution.
- Fully funded logarithmic seed placement replaces a self-consistent residual
  embryo and planetesimal population. Survivors omitted by eligibility or
  output capacity are aggregated, so their individual orbits and environments
  are not available.
- Cooling, local supply, gap depth, and two attractors approximate rather than
  solve envelope growth and disk torques. Resonant capture is absent.
- Collision retention, analytic scattering, conditional outcome probabilities,
  and the encounter-limit ejection fallback omit phase geometry and can bias
  survivor and debris distributions.
- The analytic Hill filter cannot certify long-term stability or resonance.
- Boil-off, core-powered loss, energy-limited XUV escape, and radius are not
  coupled thermal-structure solvers.
- The hard cosmic-shoreline boundary omits atmospheric species, diffusion
  limits, and transitional survival behavior.
- Pressure and gray optical depth can become unrealistically large.
- The climate loop lacks clouds, circulation, chemistry, topography, seasons,
  and internal heat.
- Moon formation rates and mass budgets are not yet ensemble-calibrated.
- The moon model omits tides, resonances, captured irregulars, and rings.

These limitations are acceptable for V1 only because the output retains its
underlying facts, complete calibration, version, and known construction model.

## Reference Context

- [Bern Generation III population synthesis](https://arxiv.org/abs/2007.05561)
  motivates end-to-end causal formation and long-term evolution.
- [MIST](https://arxiv.org/abs/1604.08592) is the intended reference class for
  replacing analytic stellar proxies with bundled versioned tracks.
- [Pu and Wu](https://arxiv.org/abs/1502.05449) motivate the ordinary final
  mutual-Hill spacing scale, without turning it into a stability proof.
- [Zahnle and Catling](https://arxiv.org/abs/1702.03386) motivate the empirical
  fourth-power atmosphere-retention trend.
- [Lopez and Fortney](https://arxiv.org/abs/1311.0329) motivate radius dependence
  on envelope fraction, mass, irradiation, and age.
- [Domingos, Winter, and Yokoyama](https://articles.adsabs.harvard.edu/pdf/2006MNRAS.373.1227D)
  motivate the fraction-of-Hill satellite stability bound.

## Related Articles

- <doc:Star-System-Generation>
- <doc:Game-Content-Architecture>
- <doc:Engine-Architecture>
