//
//  SInputHistory.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

/// Records compact practice-mode input snapshots after mapping and camera use.
struct SInputHistory: System {
    mutating func update(world: inout World, deltaTime: Float) {
        world.input.recordHistoryFrame()
    }
}
