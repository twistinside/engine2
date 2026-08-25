/// Builds a visible, gravity-ready planar reference model of the Solar System.
///
/// Planet components use JPL planet masses and volumetric mean radii; the Sun
/// uses Engine2's solar constants. Fixed planar positions flatten JPL's Table 1
/// J2000 elements to zero inclination, use its Earth-Moon barycenter entry for
/// Earth, and pair those positions with two-body conic velocities. This is a
/// deterministic gravity and presentation fixture, not a high-precision
/// ephemeris or collision-safe model. Symbolic model radii and an AU-scale
/// camera keep every body visible without changing its physical facts. Focused
/// coverage qualifies 108,000 one-hour integration steps, equivalent to 30
/// minutes at an ideal 60-tick-per-second request rate.
struct SolarSystemWorldBuilder: PWorldBuilder {
    private static let sun = SolarSystemBody.InitialState(
        mass: .sun,
        physicalRadius: .solarRadius,
        position: .zero,
        velocity: .zero,
        symbolicModelRadiusMeters: 3.0e10,
        materialID: .goldMetalSmooth
    )

    private static let mercury = SolarSystemBody.InitialState(
        mass: AstronomicalMass(kilograms: 3.30103e23),
        physicalRadius: AstronomicalDistance(meters: 2_439_400),
        position: SIMD3<Double>(
            -1.92927313431e10,
            -6.70637237842e10,
            0
        ),
        velocity: SIMD3<Double>(
            37_192.291528,
            -11_339.705425,
            0
        ),
        symbolicModelRadiusMeters: 2.0e10,
        materialID: .warmDielectricRough
    )

    private static let venus = SolarSystemBody.InitialState(
        mass: AstronomicalMass(kilograms: 4.86731e24),
        physicalRadius: AstronomicalDistance(meters: 6_051_800),
        position: SIMD3<Double>(
            -1.07635528338e11,
            -4.85095648110e9,
            0
        ),
        velocity: SIMD3<Double>(
            1_399.309886,
            -35_144.009928,
            0
        ),
        symbolicModelRadiusMeters: 2.5e10,
        materialID: .goldMetalRough
    )

    private static let earth = SolarSystemBody.InitialState(
        mass: AstronomicalMass(kilograms: 5.97217e24),
        physicalRadius: AstronomicalDistance(meters: 6_371_008.4),
        position: SIMD3<Double>(
            -2.65044416153e10,
            1.44693227461e11,
            0
        ),
        velocity: SIMD3<Double>(
            -29_786.950308,
            -5_478.861226,
            0
        ),
        symbolicModelRadiusMeters: 2.6e10,
        materialID: .warmDielectricSmooth
    )

    private static let mars = SolarSystemBody.InitialState(
        mass: AstronomicalMass(kilograms: 6.41691e23),
        physicalRadius: AstronomicalDistance(meters: 3_389_500),
        position: SIMD3<Double>(
            2.08104272945e11,
            -2.05725760647e9,
            0
        ),
        velocity: SIMD3<Double>(
            1_158.164783,
            26_302.922298,
            0
        ),
        symbolicModelRadiusMeters: 2.2e10,
        materialID: .warmDielectric
    )

    private static let jupiter = SolarSystemBody.InitialState(
        mass: AstronomicalMass(kilograms: 1.898125e27),
        physicalRadius: AstronomicalDistance(meters: 69_911_000),
        position: SIMD3<Double>(
            5.98310632858e11,
            4.40703569291e11,
            0
        ),
        velocity: SIMD3<Double>(
            -7_917.902103,
            11_143.183584,
            0
        ),
        symbolicModelRadiusMeters: 7.0e10,
        materialID: .goldMetal
    )

    private static let saturn = SolarSystemBody.InitialState(
        mass: AstronomicalMass(kilograms: 5.68317e26),
        physicalRadius: AstronomicalDistance(meters: 58_232_000),
        position: SIMD3<Double>(
            9.60735589080e11,
            9.79698820759e11,
            0
        ),
        velocity: SIMD3<Double>(
            -7_417.135462,
            6_740.245789,
            0
        ),
        symbolicModelRadiusMeters: 6.5e10,
        materialID: .goldMetalRough
    )

    private static let uranus = SolarSystemBody.InitialState(
        mass: AstronomicalMass(kilograms: 8.68099e25),
        physicalRadius: AstronomicalDistance(meters: 25_362_000),
        position: SIMD3<Double>(
            2.15824979865e12,
            -2.05518866143e12,
            0
        ),
        velocity: SIMD3<Double>(
            4_643.679151,
            4_611.969282,
            0
        ),
        symbolicModelRadiusMeters: 4.5e10,
        materialID: .warmDielectricSmooth
    )

    private static let neptune = SolarSystemBody.InitialState(
        mass: AstronomicalMass(kilograms: 1.024092e26),
        physicalRadius: AstronomicalDistance(meters: 24_622_000),
        position: SIMD3<Double>(
            2.51373719503e12,
            -3.73905236012e12,
            0
        ),
        velocity: SIMD3<Double>(
            4_474.992029,
            3_063.689825,
            0
        ),
        symbolicModelRadiusMeters: 4.5e10,
        materialID: .warmDielectric
    )

    private static let referenceBodies = [
        sun,
        mercury,
        venus,
        earth,
        mars,
        jupiter,
        saturn,
        uranus,
        neptune
    ]

    private static let referenceCamera = Camera.lookingAt(
        .zero,
        from: SIMD3<Float>(0, 0, 8.0e12),
        up: SIMD3<Float>(0, 1, 0),
        projection: .perspective(
            verticalFieldOfView: .pi / 3,
            near: 1.0e10,
            far: 4.0e13
        )
    )

    func buildWorld() -> World {
        let world = World()
        world.camera = Self.referenceCamera

        for body in Self.referenceBodies {
            _ = SolarSystemBody(in: world, from: body)
        }

        return world
    }
}
