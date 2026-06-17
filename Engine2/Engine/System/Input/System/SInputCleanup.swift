//
//  SInputCleanup.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

/// Clears one-step input deltas after every fixed input step.
struct SInputCleanup: PSystem {
    mutating func update(world: inout World, deltaTime: Float) {
        world.input.clearTransientInput()
    }
}
