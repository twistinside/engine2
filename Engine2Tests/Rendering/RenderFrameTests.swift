//
//  RenderFrameTests.swift
//  Engine2Tests
//
//  Created by Codex on 5/31/26.
//

import Testing
@testable import Engine2

struct RenderFrameTests {
    @Test func extractCreatesInstancesFromPositionComponents() async throws {
        let world = World()
        let first = EntityID(index: 0, generation: 0)
        let second = EntityID(index: 1, generation: 0)

        world.positionComponents.insert(CPosition(position: SIMD3<Float>(2, -4, 0)), for: first)
        world.positionComponents.insert(CPosition(position: SIMD3<Float>(-1, 3, 0)), for: second)

        let frame = RenderFrame.extract(from: world)

        #expect(
            frame.instances == [
                RenderInstance(worldPosition: SIMD3<Float>(2, -4, 0)),
                RenderInstance(worldPosition: SIMD3<Float>(-1, 3, 0))
            ]
        )
    }
}
