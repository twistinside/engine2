import simd
@testable import Engine2

/// Registers complete production entities for missile tests that exercise structural changes.
struct MissileTestScene {
    var world: World
    let skiff: MiningSkiff

    init(velocity: SIMD3<Double>) {
        let world = World()
        let primary = MissileTestPrimary(in: world, from: Entity.InitialState(position: .zero))
        self.world = world
        skiff = MiningSkiff(
            in: world,
            name: "Launcher",
            primaryEntityID: primary.id,
            position: .zero,
            velocity: velocity,
            physicalRadius: 1,
            dryMass: 1,
            fuelCapacity: 1,
            cargoCapacity: 1,
            maximumThrust: 1,
            exhaustVelocity: 1,
            missileSpeed: 100,
            missileLifetime: 5,
            missileRadius: 1,
            materialID: .goldMetal
        )
        world.select(skiff.id)
    }

    func asteroid(at position: SIMD3<Double>, velocity: SIMD3<Double>) -> Asteroid {
        let primary = MissileTestPrimary(
            in: world,
            from: Entity.InitialState(position: position - SIMD3<Double>(1, 0, 0))
        )
        let asteroid = Asteroid(
            in: world,
            name: "Target",
            primaryEntityID: primary.id,
            orbitalRadius: 1,
            angularSpeed: 0,
            phase: 0,
            physicalRadius: 1,
            ore: 10,
            interactionRange: 1,
            miningRate: 1,
            materialID: .warmDielectric
        )
        world.components[OrbitalRailComponent.self].update(for: asteroid.id) { rail in
            rail.velocity = velocity
        }
        return asteroid
    }

    func depot(at position: SIMD3<Double>) -> MiningDepot {
        let primary = MissileTestPrimary(
            in: world,
            from: Entity.InitialState(position: position - SIMD3<Double>(1, 0, 0))
        )
        return MiningDepot(
            in: world,
            name: "Solid",
            primaryEntityID: primary.id,
            orbitalRadius: 1,
            angularSpeed: 0,
            phase: 0,
            physicalRadius: 1,
            interactionRange: 1,
            unloadingRate: 1,
            refuelingRate: 1,
            materialID: .goldMetal
        )
    }

    func missile(
        at position: SIMD3<Double>,
        velocity: SIMD3<Double>,
        lifetime: Double
    ) -> Missile {
        Missile(
            in: world,
            ownerEntityID: skiff.id,
            position: position,
            velocity: velocity,
            radius: 1,
            lifetime: lifetime
        )
    }

    mutating func move(deltaTime: Double) {
        var capture = PreviousPositionCaptureSystem()
        capture.update(world: &world, deltaTime: deltaTime)
        var movement = MovementSystem()
        movement.update(world: &world, deltaTime: deltaTime)
    }
}
