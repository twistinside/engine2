//
//  SInputMapping.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

/// Converts raw input state into engine-level action values.
struct SInputMapping: System {
    var pointerOrbitSensitivity: Float = 0.01
    var scrollZoomSensitivity: Float = 0.04

    mutating func update(world: inout World, deltaTime: Float) {
        world.input.actions.cameraOrbitDelta = world.input.mouse.delta * pointerOrbitSensitivity
        world.input.actions.cameraZoomDelta = world.input.mouse.scrollDelta.y * scrollZoomSensitivity
    }
}
