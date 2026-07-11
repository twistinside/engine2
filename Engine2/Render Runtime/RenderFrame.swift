//
//  RenderFrame.swift
//  Engine2
//
//  Created by Codex on 5/31/26.
//

import simd

/// Flat presentation data extracted from ECS state for one render pass.
struct RenderFrame: Equatable {
    static let empty = RenderFrame(camera: Camera(), instances: [])

    var camera: Camera
    var instances: [RenderInstance]

    /// Builds a renderer-facing snapshot from authoritative ECS component rows.
    static func extract(from world: World) -> RenderFrame {
        let instances = world.positionComponents.entities.compactMap { entity -> RenderInstance? in
            guard let position = world.positionComponents[entity]?.position else {
                return nil
            }

            return RenderInstance(
                transform: Transform(
                    position: position,
                    rotation: world.rotationComponents[entity]?.rotation ?? Transform.identityRotation,
                    scale: world.scaleComponents[entity]?.scale ?? RenderInstance.defaultScale
                )
            )
        }

        return RenderFrame(camera: world.camera, instances: instances)
    }
}

/// Minimal per-entity presentation state.
struct RenderInstance: Equatable {
    /// Default world-space size for renderable entities that do not advertise scale yet.
    static let defaultScale = SIMD3<Float>(repeating: 0.5)

    var transform: Transform

    init(transform: Transform) {
        self.transform = transform
    }

    init(
        worldPosition: SIMD3<Float>,
        rotation: simd_quatf = Transform.identityRotation,
        scale: SIMD3<Float> = defaultScale
    ) {
        self.transform = Transform(
            position: worldPosition,
            rotation: rotation,
            scale: scale
        )
    }
}
