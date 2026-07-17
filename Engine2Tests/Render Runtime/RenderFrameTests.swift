//
//  RenderFrameTests.swift
//  Engine2Tests
//
//  Created by Codex on 5/31/26.
//

import simd
import Testing
@testable import Engine2

struct RenderFrameTests {
    @Test func projectionCreatesInstancesFromPublishedPresentationFacts() async throws {
        let world = World()
        let first = EntityID(index: 0, generation: 0)
        let second = EntityID(index: 1, generation: 0)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(2, -4, 0)), for: first)
        world.positionComponents.insert(CPosition(position: SIMD3<Float>(-1, 3, 0)), for: second)
        world.renderableComponents.insert(CRenderable(meshID: .ball), for: first)
        world.renderableComponents.insert(CRenderable(meshID: .ball), for: second)

        let snapshot = SimulationPresentationSnapshot.capture(
            from: world,
            at: SimulationTick(rawValue: 7)
        )
        let frame = RenderFrame.project(from: snapshot)

        #expect(frame.sourceTick == SimulationTick(rawValue: 7))
        #expect(
            frame.instances == [
                RenderInstance(meshID: .ball, worldPosition: SIMD3<Float>(2, -4, 0)),
                RenderInstance(meshID: .ball, worldPosition: SIMD3<Float>(-1, 3, 0))
            ]
        )
    }

    @Test func projectionIgnoresPositionedEntitiesWithoutPresentationContent() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(2, -4, 0)), for: entity)

        let snapshot = SimulationPresentationSnapshot.capture(from: world, at: .zero)

        #expect(snapshot.entityPresentations.isEmpty)
        #expect(RenderFrame.project(from: snapshot).instances.isEmpty)
    }

    @Test func projectionIgnoresRenderableEntitiesWithoutPositions() {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        world.renderableComponents.insert(
            CRenderable(meshID: .ball),
            for: entity
        )

        let snapshot = SimulationPresentationSnapshot.capture(from: world, at: .zero)

        #expect(snapshot.entityPresentations.map(\.id) == [entity])
        #expect(RenderFrame.project(from: snapshot).instances.isEmpty)
    }

    @Test func projectionIncludesCameraRotationAndScale() async throws {
        let world = World()
        let entity = EntityID(index: 0, generation: 0)
        let rotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))
        let scale = SIMD3<Float>(2, 3, 4)

        world.camera = Camera(position: SIMD3<Float>(1, 2, 3), orthographicHeight: 12)
        world.positionComponents.insert(CPosition(position: SIMD3<Float>(3, 4, 5)), for: entity)
        world.renderableComponents.insert(CRenderable(meshID: .ball), for: entity)
        world.rotationComponents.insert(CRotation(rotation: rotation), for: entity)
        world.scaleComponents.insert(CScale(scale: scale), for: entity)

        let snapshot = SimulationPresentationSnapshot.capture(from: world, at: .zero)
        let frame = RenderFrame.project(from: snapshot)

        #expect(frame.camera == world.camera)
        #expect(
            frame.instances == [
                RenderInstance(
                    meshID: .ball,
                    transform: Transform(
                        position: SIMD3<Float>(3, 4, 5),
                        rotation: rotation,
                        scale: scale
                    )
                )
            ]
        )
    }
}
