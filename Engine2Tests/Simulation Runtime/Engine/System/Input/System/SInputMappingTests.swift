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

        world.input.ingest(
            InputSnapshot(
                revision: InputRevision(session: 1, sequence: 1),
                pointerPosition: .zero,
                pointerMotionTotal: SIMD2<Float>(4, -3),
                scrollTotal: SIMD2<Float>(0, 5),
                pressedMouseButtons: [],
                pressedKeys: []
            )
        )

        system.update(world: &world, deltaTime: 1)

        #expect(world.input.actions.cameraOrbitDelta == SIMD2<Float>(2, -1.5))
        #expect(world.input.actions.cameraZoomDelta == 10)
    }
}
