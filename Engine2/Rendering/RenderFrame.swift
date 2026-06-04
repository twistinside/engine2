//
//  RenderFrame.swift
//  Engine2
//
//  Created by Codex on 5/31/26.
//

/// Flat presentation data extracted from ECS state for one render pass.
struct RenderFrame: Equatable {
    static let empty = RenderFrame(instances: [])

    var instances: [RenderInstance]

    /// Builds a renderer-facing snapshot from authoritative ECS component rows.
    static func extract(from world: World) -> RenderFrame {
        let instances = world.positionComponents.entities.compactMap { entity -> RenderInstance? in
            guard let position = world.positionComponents[entity]?.position else {
                return nil
            }

            return RenderInstance(worldPosition: position)
        }

        return RenderFrame(instances: instances)
    }
}

/// Minimal per-entity presentation state.
struct RenderInstance: Equatable {
    /// Clip-space translation used by the temporary renderer.
    ///
    /// This is intentionally presentation data, not ECS state. A future camera
    /// or render extraction stage should replace this fixed world-to-clip scale.
    var clipPosition: SIMD2<Float>
    var scale: Float

    init(worldPosition: SIMD3<Float>, scale: Float = 0.12) {
        self.clipPosition = SIMD2<Float>(worldPosition.x, worldPosition.y) / 4
        self.scale = scale
    }
}
