import Testing
import simd
@testable import Engine2

struct WorldInitialStateTests {
    @Test func rejectsHealthWithoutDamageableCapability() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Entity(in: World(), from: Entity.InitialState(health: 1))
            }
        }
    }

    @Test func rejectsMissingHealthForDamageableCapability() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = NonphysicalDamageableTestEntity(in: World(), from: .empty)
            }
        }
    }

    @Test func rejectsZeroInitialHealth() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = NonphysicalDamageableTestEntity(in: World(), from: Entity.InitialState(health: 0))
            }
        }
    }

    @Test func rejectsContactDamageWithoutContactDamagingCapability() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Entity(in: World(), from: Entity.InitialState(contactDamage: 1))
            }
        }
    }

    @Test func rejectsMissingDamageForContactDamagingCapability() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = PersistentContactDamageTestEntity(
                    in: World(),
                    from: Entity.InitialState(collisionRadius: 1, collisionResponse: .sensor)
                )
            }
        }
    }

    @Test func rejectsZeroContactDamage() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = PersistentContactDamageTestEntity(
                    in: World(),
                    from: Entity.InitialState(collisionRadius: 1, collisionResponse: .sensor, contactDamage: 0)
                )
            }
        }
    }

    @Test func rejectsCollisionOwnerPolicyWithoutCollidableCapability() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Entity(in: World(), from: Entity.InitialState(collisionOwnerPolicy: .exclude))
            }
        }
    }

    @Test func rejectsCollisionContactScopeWithoutCollidableCapability() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Entity(in: World(), from: Entity.InitialState(collisionContactScope: .solidBodies))
            }
        }
    }

    @Test func railSpawnUsesThePrimarysLivePositionBeforeAnyTick() throws {
        let world = World()
        let primary = Ball(in: world, materialID: .goldMetal)
        let primaryPosition = SIMD3<Double>(120, -30, 7)
        world.positionComponents.update(for: primary.id) { $0.position = primaryPosition }
        let entity = InitialStateRailEntity(in: world, from: Entity.InitialState(
            collisionRadius: 2,
            collisionResponse: .solid(restitution: 0.35),
            orbitalPrimaryID: primary.id,
            orbitalRadius: 20,
            orbitalAngularSpeed: -0.25,
            orbitalPhase: .pi / 2,
            meshID: .ball,
            materialID: .goldMetal
        ))

        let expectedPosition = SIMD3<Double>(120, -10, 7)
        let expectedVelocity = SIMD3<Double>(5, 0, 0)
        let rail = try #require(world.orbitalRailComponents[entity.id])
        #expect(rail.elapsedTime == 0)
        #expect(simd_distance(entity.position, expectedPosition) < 1e-12)
        #expect(simd_distance(entity.orbitalVelocity, expectedVelocity) < 1e-12)
        #expect(world.previousPositionComponents[entity.id]?.position == entity.position)
        #expect(world.motionComponents[entity.id] == nil)
        #expect(world.entity(for: entity.id) === entity)

        let snapshot = world.presentationSnapshot(
            at: SimulationCursor(sessionID: SimulationSessionID(), tick: .zero)
        )
        let presentation = try #require(snapshot.entityPresentations.first { $0.id == entity.id })
        #expect(presentation.position == expectedPosition.singlePrecision)
    }

    @Test func reseedingARailRestartsItFromTheCurrentPrimary() throws {
        let world = World()
        let primary = Ball(in: world, materialID: .goldMetal)
        let state = Entity.InitialState(
            collisionRadius: 2,
            collisionResponse: .solid(restitution: 0.35),
            orbitalPrimaryID: primary.id,
            orbitalRadius: 20,
            orbitalAngularSpeed: 0.25,
            orbitalPhase: 0,
            meshID: .ball,
            materialID: .goldMetal
        )
        let entity = InitialStateRailEntity(in: world, from: state)
        world.orbitalRailComponents.update(for: entity.id) {
            $0.elapsedTime = 10
            $0.velocity = .zero
        }
        world.positionComponents.update(for: primary.id) { $0.position = SIMD3<Double>(40, 50, 60) }

        world.add(entity, from: state)

        #expect(entity.position == SIMD3<Double>(60, 50, 60))
        #expect(entity.orbitalVelocity == SIMD3<Double>(0, 5, 0))
        #expect(world.orbitalRailComponents[entity.id]?.elapsedTime == 0)
        #expect(world.previousPositionComponents[entity.id]?.position == entity.position)
        #expect(world.orbitalRailComponents.entities.count == 1)
    }

    @Test func runtimePublishesCompleteRailPlacementAtTickZero() throws {
        let runtime = SimulationRuntime(
            worldBuilder: MiningWorldBuilder(),
            configuration: .miningGame,
            behavior: MiningSimulationBehavior(),
            inputBaseline: nil
        )
        let world = runtime.world
        let snapshot = runtime.latestPresentationSnapshot

        #expect(snapshot.cursor.tick == .zero)
        #expect(world.orbitalRailComponents.entities.count == 7)
        for id in world.orbitalRailComponents.entities {
            let rail = try #require(world.orbitalRailComponents[id])
            let primary = try #require(world.positionComponents[rail.primaryEntityID])
            let expected = rail.state(relativeTo: primary.position)
            let presentation = try #require(snapshot.entityPresentations.first { $0.id == id })
            #expect(rail.elapsedTime == 0)
            #expect(world.positionComponents[id]?.position == expected.position)
            #expect(world.previousPositionComponents[id]?.position == expected.position)
            #expect(rail.velocity == expected.velocity)
            #expect(presentation.position == expected.position.singlePrecision)
        }
    }

    @Test func rejectsIncompleteRailParametersForOrbitingEntity() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Ball(in: world, materialID: .goldMetal)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primary.id,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsMeshWithoutMaterialForRenderableEntity() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Ball(in: world, materialID: .goldMetal)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primary.id,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball
                ))
            }
        }
    }

    @Test func rejectsCollisionResponseWithoutCollidableCapability() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Entity(in: World(), from: Entity.InitialState(collisionResponse: .solid(restitution: 0.35)))
            }
        }
    }

    @Test func rejectsOrbitalPhaseWithoutOrbitingCapability() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Entity(in: World(), from: Entity.InitialState(orbitalPhase: 0))
            }
        }
    }

    @Test func rejectsMissingPrimary() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primaryID = EntityID(index: 90, generation: 0)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primaryID,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsStalePrimaryGeneration() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Ball(in: world, materialID: .goldMetal)
                let primaryID = EntityID(index: primary.id.index, generation: primary.id.generation + 1)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primaryID,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsDestroyedPrimary() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Ball(in: world, materialID: .goldMetal)
                world.destroy(primary.id)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primary.id,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsUnregisteredPrimaryEvenWithAPositionRow() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primaryID = world.reserveEntityID()
                world.positionComponents.insert(PositionComponent(position: .zero), for: primaryID)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primaryID,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsPrimaryWithoutPosition() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Entity(in: world, from: .empty)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primary.id,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsNonfinitePrimaryPosition() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Ball(in: world, materialID: .goldMetal)
                world.positionComponents.update(for: primary.id) { $0.position = SIMD3<Double>(.nan, 0, 0) }
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primary.id,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsExplicitPlacementAlongsideRail() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Ball(in: world, materialID: .goldMetal)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    position: .zero,
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primary.id,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsExplicitMotionAlongsideRail() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Ball(in: world, materialID: .goldMetal)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    velocity: .zero,
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primary.id,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsNonfiniteDerivedRailVelocity() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Ball(in: world, materialID: .goldMetal)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primary.id,
                    orbitalRadius: 1e200,
                    orbitalAngularSpeed: 1e200,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsRailThatNamesItsOwnReservedIdentity() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let entity = InitialStateRailEntity(unregisteredID: world.reserveEntityID(), in: world)
                world.add(entity, from: Entity.InitialState(
                    collisionRadius: 2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: entity.id,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }

    @Test func rejectsDynamicAndRailCapabilitiesOnOneEntity() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Ball(in: world, materialID: .goldMetal)
                _ = InitialStateDynamicRailEntity(in: world, from: Entity.InitialState(
                    orbitalPrimaryID: primary.id,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0
                ))
            }
        }
    }

    @Test func rejectsInvalidAuthoredCollisionDataAtRegistration() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let primary = Ball(in: world, materialID: .goldMetal)
                _ = InitialStateRailEntity(in: world, from: Entity.InitialState(
                    collisionRadius: -2,
                    collisionResponse: .solid(restitution: 0.35),
                    orbitalPrimaryID: primary.id,
                    orbitalRadius: 20,
                    orbitalAngularSpeed: 0.25,
                    orbitalPhase: 0,
                    meshID: .ball,
                    materialID: .goldMetal
                ))
            }
        }
    }
}
