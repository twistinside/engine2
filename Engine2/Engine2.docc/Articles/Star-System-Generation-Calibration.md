# Star System Generation Calibration

This article records the exact `coreAccretionLiteV1` calibration implemented by
``StarSystemGenerationPolicy`` and its phase collaborators. It separates sampled
priors, analytic physical approximations, population-tuning coefficients, and
numerical safety limits.

## Status

Implemented V1 reference.

Changing any value or equation in this article changes generated output and
requires a new ``StarSystemGenerationModelVersion``. Correcting documentation to
match unchanged code does not require a new model version.

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
| Maximum embryos | `64` | Numerical control |
| Gas-disk epochs | `96` | Numerical control |
| Present-evolution epochs | `48` | Numerical control |
| Eccentricity damping passes | `32` | Numerical control |
| Climate iterations | `6` | Numerical control |
| Maximum significant moons per planet | `4` | Numerical control |

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

The formation domain is reserved in V1 even though the current deterministic
formation equations consume no random draws after placement. Reserving its raw
address avoids reusing a semantic lane later.

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
| Disk | log-normal mass ratio; log-normal lifetime; log-normal characteristic radius; normal density exponent; normal iron fraction; dry-water unit draw; conditional wet-water uniform; normal solid-fraction scatter |
| Embryos | initial-radius uniform; one multiplicative-spacing uniform after each placement attempt |
| Formation | no draws; the domain remains reserved |
| Orbital excitation | per-body Rayleigh eccentricity; normal inclination |
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
presentXUVFactor = fXUV / 1e-5
historicXUVFactor = min(
    100,
    presentXUVFactor * max(intervalAge / finalAge, 0.002)^(-1.2)
)
```

The sampled activity regime therefore affects escape through `fXUV`; the
resolver does not maintain a second independent activity multiplier.

## Disk Priors

| Quantity | V1 calibration | Category |
| --- | --- | --- |
| Gas-to-star mass ratio | Base-10 log-normal, median `0.02`, scatter `0.5 dex` | Sampled prior |
| Gas-to-star clamp | `0.003...0.20` | Numerical control |
| Disk lifetime | Base-10 log-normal, median `3 Myr`, scatter `0.25 dex` | Sampled prior |
| Lifetime clamp | `1...10 Myr` | Numerical control |
| Characteristic radius | Base-10 log-normal, median `30 sqrt(Mstar) AU`, scatter `0.25 dex` | Sampled prior |
| Characteristic-radius clamp | `10...100 AU` | Numerical control |
| Surface-density exponent | Normal `(1.0, 0.2)`, clamped `0.5...1.5` | Sampled prior |
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

## Disk Geometry and Normalization

The inner edge is:

```text
ainner = max(0.03 AU, 1.15 Rstar)
```

The outer edge is:

```text
aouter = max(4 ainner, min(40 AU, 3 Rc))
```

The annulus edges are logarithmically spaced. For each annulus with geometric
center `a` and width `delta-a`:

```text
x = a / Rc
SigmaShape = x^(-p) exp(-x^(2 - p))
w = 2 pi a delta-a SigmaShape
```

Every weight is divided by the sum of all 128 weights. Gas and solid masses use
the same normalized radial weights. Category: physical approximation plus
numerical normalization.

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

For one placement, V1 sums available solids in the five-annulus neighborhood.
It withdraws:

```text
fwithdraw = min(seedTarget / availableSolid, 1)
```

from every neighborhood annulus. This preserves the local aggregate mixture.
Identity is `fundedEmbryoIndex + 1`. Unfunded placements do not consume an
identity.

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

## Primordial Envelope Target

At elapsed disk time `T` in Myr:

```text
ftarget = min(
    0.95,
    0.0025 Msolid^1.7 (1 - exp(-T))
)

MtargetEnvelope = Msolid ftarget / max(1 - ftarget, 0.05)

captureResponse = 1 - exp(-5.2 gasAccretionEfficiency delta-t)
Mrequested = max(0, MtargetEnvelope - McurrentEnvelope)
           * captureResponse
```

`gasAccretionEfficiency` is `0.60`.

Category: population calibration.

Requested gas is distributed across feeding-zone annuli in proportion to their
current gas masses. Contested gas requests scale by
`min(1, available/requested)`. V1 has no explicit gap-opening or local viscous
supply solver.

## Migration and Disk Dispersal

Global gas availability is:

```text
fgas = remainingAnnulusGas / initialDiskGas
```

For epoch duration `delta-t` in Myr, inward migration is:

```text
rateMigration = 0.384 / Myr
              * migrationEfficiency
              * Mtotal / (1 + Mtotal / 30)
              * fgas

fmigration = min(0.03, 1 - exp(-rateMigration delta-t))
```

`migrationEfficiency` is `0.18`. The new radius is:

```text
anew = max(1.1 ainner, a (1 - fmigration))
```

Category: population calibration and numerical control.

Each epoch then multiplies all unbound gas by:

```text
exp(-3 delta-t / tdisk)
```

The removed difference enters dispersed gas. After the final epoch, all
remaining annulus gas also enters dispersed gas. Category: physical
approximation.

## Formation Mergers

Every eighth epoch, and once after the last epoch, adjacent bodies with fewer
than `3.5` mutual Hill radii merge. This is the persisted
`formationMergerSpacing` calibration. The array sorts by semimajor axis, then
stable identity. The first failing pair merges and the scan restarts.

Identity and progenitor rules are:

```text
mergedID = min(firstID, secondID)
mergedProgenitorCount = firstCount + secondCount
```

All composition masses add without loss. The merged semimajor axis is:

```text
aMerged = ((m1 sqrt(a1) + m2 sqrt(a2)) / (m1 + m2))^2
```

Category: physical approximation and deterministic tie-break.

## Final Architecture Filter

Required mutual-Hill spacing is:

| Pair | Required spacing |
| --- | ---: |
| Both below `30 Earth masses` | `12` |
| Either at least `30 Earth masses` | `15` |

Category: population calibration and conservative construction filter.

The ordinary value is motivated by the clustering Pu and Wu report for compact
Kepler systems. The giant value is an additional Engine2 margin, not a threshold
from that study.

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

The resolver integrates 48 logarithmic intervals from `0.01 Gyr` to the sampled
system age.

At midpoint age `t`, the stored present XUV fraction drives historic exposure:

```text
presentXUVFactor = fXUV / 1e-5
historicXUVFactor = min(
    100,
    presentXUVFactor * max(t / finalAge, 0.002)^(-1.2)
)
```

With current total mass `M`, resolved radius `R`, and mean flux `S`:

```text
binding = M^2 / max(R^3 * max(S, 1e-6) * historicXUVFactor, 1e-9)
epochWeight = (upperAge - lowerAge) / finalAge
lossExponent = atmosphereEscapeEfficiency
             * epochWeight
             * 80 / (binding + 2)
Mgas,new = Mgas,old * exp(-min(lossExponent, 4))
```

`atmosphereEscapeEfficiency` is `0.10`.

Category: physical approximation and population calibration.

This is not the energy-limited escape equation. It is a smooth V1 binding proxy
chosen to preserve the expected dependencies on mass, radius, irradiation,
activity, and time. Retained hydrogen-helium below `1e-12 Earth masses` is set
to exactly zero after the last interval.

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

R = min(10, max(Rsolid, Rsolid + delta-R))
```

If envelope fraction is at least `0.5` and mass is at least `30 Earth masses`:

```text
R = clamp(10.5 + 0.6 log10(max(M / 100, 0.1)), 8, 14)
```

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

survival = 1 / (1 + exp(-3 (q + 0.25)))
geologicSupply = M / (M + 0.3)
accessibleVolatiles = Mwater + MotherVolatiles

MsecondaryAtmosphere = accessibleVolatiles
                     * 0.0001
                     * survival
                     * geologicSupply
```

Category: physical approximation and population calibration.

The fourth-power shoreline trend comes from Zahnle and Catling. The sigmoid
zero point, slope, supply fraction, and geologic term are V1 calibrations.

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
bodies; otherwise it derives global ocean, partial liquid, ice, or dry from the
resolved coverage and inventory.

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
| Exposed surface pressure at least `1e-5 bar` | Tenuous |
| Otherwise | Airless |

Deep envelopes produce an opaque visible boundary. All other atmosphere regimes
produce an exposed-solid boundary in V1.

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
6. Otherwise: ice covered.

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

The normal unit suite pins the first random words and three canonical resolved
system fingerprints. It also validates same-seed equality, serialization,
corruption rejection, conservation, stellar and disk bounds, orbit and moon
stability, causal environment trends, both moon origins, and exact coverage of
all V1 bulk, atmosphere, thermal, water, and visible-boundary regimes across a
bounded 32-seed smoke ensemble. These are regression contracts, not
occurrence-rate calibration.

## Expected Population Audits

Ordinary unit tests prove causal and invariant behavior. Calibration requires a
separate large-seed audit that records, at minimum:

- generated failure count and reason
- planet and significant-moon count distributions
- stellar mass, metallicity, age, and luminosity distributions
- disk gas, solid, radius, and lifetime distributions
- retained and unresolved mass fractions
- planet mass, radius, semimajor axis, eccentricity, and composition quantiles
- primordial-envelope occurrence by mass and flux
- physical-state cross-tabulations
- minimum final Hill spacing
- conservation residual maxima
- generation operation time and peak memory

Occurrence-rate targets must live in an audit specification beside the model
version. Do not add tight noisy population percentages to the normal unit suite.

## Known V1 Biases

V1 is expected to bias output in these ways:

- A narrow stellar-mass range omits abundant lower-mass red dwarfs and all
  higher-mass main-sequence stars.
- Smooth stellar proxies omit track structure and pre-main-sequence duration.
- Identical gas and solid surface-density weights omit radial drift and local
  dust evolution.
- Logarithmic placement ratios replace self-consistent oligarchic spacing.
- Perfect mergers retain too much solid and volatile material.
- Inward-only migration overproduces trapped inner architectures unless later
  calibration compensates.
- Merging every final unstable pair suppresses ejected planets and dynamically
  hot survivors.
- The analytic Hill filter cannot certify long-term stability or resonance.
- Envelope targets, escape, and radius are not structure solvers.
- The secondary-atmosphere model omits atmospheric species and diffusion limits.
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
