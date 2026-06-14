//
//  SInputMappingTests.swift
//  Engine2Tests
//
//  Created by Codex on 6/14/26.
//

import simd
import Testing
@testable import Engine2

struct SInputMappingTests {
    @Test func mapsPointerAndScrollIntoCameraActions() async throws {
        var world = World()
        var system = SInputMapping(pointerOrbitSensitivity: 0.5, scrollZoomSensitivity: 2)

        world.input.apply(.mouseDragged(delta: SIMD2<Float>(4, -3), position: .zero))
        world.input.apply(.scroll(delta: SIMD2<Float>(0, 5)))

        system.update(world: &world, deltaTime: 1)

        #expect(world.input.actions.cameraOrbitDelta == SIMD2<Float>(2, -1.5))
        #expect(world.input.actions.cameraZoomDelta == 10)
    }
}
