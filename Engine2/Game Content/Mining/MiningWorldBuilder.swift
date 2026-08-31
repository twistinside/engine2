import Foundation
import simd

/// Builds the deterministic nine-body mining vertical slice.
struct MiningWorldBuilder: PWorldBuilder {
    static let cameraHeight: Float = 1_200
    static let cameraPlanarOffset: Float = 400
    static let cargoCapacity = 8_000.0
    static let depotOrbitRadius = 1_200.0
    static let exhaustVelocity = 20_000.0
    static let fuelCapacity = 2_000.0
    static let gravitationalParameter = 4_000_000.0
    static let maximumThrust = 300_000.0
    static let miningRate = 800.0
    static let refuelingRate = 400.0
    static let skiffDryMass = 10_000.0
    static let starRadius = 100.0
    static let unloadingRate = 1_600.0

    private let asteroidOre = [4_000.0, 5_000.0, 6_000.0, 7_000.0, 8_000.0, 9_000.0]
    private let asteroidPhases = [0.35, 1.30, 2.25, 3.20, 4.15, 5.10]
    private let asteroidRadii = [1_800.0, 2_400.0, 3_000.0, 3_600.0, 4_300.0, 5_000.0]
    private let asteroidSizes = [32.0, 38.0, 44.0, 36.0, 48.0, 42.0]

    func buildWorld() -> World {
        let world = World()
        let star = Star(
            in: world,
            name: "Helios",
            gravitationalParameter: Self.gravitationalParameter,
            mass: Self.gravitationalParameter / 6.67430e-11,
            radius: Self.starRadius,
            materialID: .goldMetalSmooth
        )

        addAsteroids(to: world, orbiting: star)

        let skiffPosition = SIMD3<Double>(Self.depotOrbitRadius, -90, 0)
        let skiff = MiningSkiff(
            in: world,
            name: "Prospector",
            primaryEntityID: star.id,
            position: skiffPosition,
            velocity: circularVelocity(at: skiffPosition),
            physicalRadius: 10,
            dryMass: Self.skiffDryMass,
            fuelCapacity: Self.fuelCapacity,
            cargoCapacity: Self.cargoCapacity,
            maximumThrust: Self.maximumThrust,
            exhaustVelocity: Self.exhaustVelocity,
            materialID: .goldMetal
        )

        _ = MiningDepot(
            in: world,
            name: "Waystation",
            primaryEntityID: star.id,
            primaryPosition: star.position,
            orbitalRadius: Self.depotOrbitRadius,
            angularSpeed: circularAngularSpeed(radius: Self.depotOrbitRadius),
            phase: 0,
            physicalRadius: 30,
            interactionRange: 140,
            unloadingRate: Self.unloadingRate,
            refuelingRate: Self.refuelingRate,
            materialID: .warmDielectricSmooth
        )

        world.select(skiff.id)
        world.cameraFollowEntityID = skiff.id
        world.camera = Camera.lookingAt(
            SIMD3<Float>(Float(skiff.position.x), Float(skiff.position.y), 0),
            from: SIMD3<Float>(
                Float(skiff.position.x),
                Float(skiff.position.y) - Self.cameraPlanarOffset,
                Self.cameraHeight
            ),
            up: SIMD3<Float>(0, 0, 1),
            projection: .perspective(verticalFieldOfView: .pi / 3, near: 1, far: 20_000)
        )
        return world
    }

    private func addAsteroids(to world: World, orbiting star: Star) {
        for index in asteroidRadii.indices {
            let orbitRadius = asteroidRadii[index]
            _ = Asteroid(
                in: world,
                name: "Asteroid \(index + 1)",
                primaryEntityID: star.id,
                primaryPosition: star.position,
                orbitalRadius: orbitRadius,
                angularSpeed: circularAngularSpeed(radius: orbitRadius),
                phase: asteroidPhases[index],
                physicalRadius: asteroidSizes[index],
                ore: asteroidOre[index],
                interactionRange: 140,
                miningRate: Self.miningRate,
                materialID: .warmDielectricRough
            )
        }
    }

    private func circularAngularSpeed(radius: Double) -> Double {
        sqrt(Self.gravitationalParameter / (radius * radius * radius))
    }

    private func circularVelocity(at position: SIMD3<Double>) -> SIMD3<Double> {
        let radius = simd_length(SIMD2<Double>(position.x, position.y))
        let speed = sqrt(Self.gravitationalParameter / radius)
        return SIMD3<Double>(-position.y / radius * speed, position.x / radius * speed, 0)
    }
}
