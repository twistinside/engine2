/// Translates the presentation camera with one authoritative entity.
///
/// Applying the target's per-tick displacement preserves the complete
/// camera-to-target offset, rotation, and projection authored by camera input.
struct CameraFollowSystem: System {
    mutating func update(world: inout World, deltaTime _: Double) {
        guard let entity = world.cameraFollowEntityID,
              world.destructibleComponents[entity]?.state == .active,
              let position = world.positionComponents[entity]?.position,
              let previousPosition = world.previousPositionComponents[entity]?.position,
              position.isFinite,
              previousPosition.isFinite else {
            return
        }

        let currentCamera = world.camera
        let displacement = position - previousPosition
        let cameraPosition = currentCamera.position + SIMD3<Float>(
            Float(displacement.x),
            Float(displacement.y),
            Float(displacement.z)
        )
        guard cameraPosition.isFinite else {
            return
        }
        world.camera = Camera(
            position: cameraPosition,
            rotation: currentCamera.rotation,
            projection: currentCamera.projection
        )
    }
}
