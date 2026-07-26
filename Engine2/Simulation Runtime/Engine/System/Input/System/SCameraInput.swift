import Foundation
import simd

/// Applies mapped orbit and zoom commands to the authoritative Simulation camera.
///
/// The system derives orbit state from `World.camera` on every meaningful tick
/// rather than retaining a second camera state. World replacement and authored
/// cameras therefore remain authoritative, while pause policy naturally freezes
/// both camera mutation and presentation publication.
struct SCameraInput: PSystem {
    let target: SIMD3<Float>
    let minimumRadius: Float
    let maximumRadius: Float

    init(target: SIMD3<Float>, minimumRadius: Float, maximumRadius: Float) {
        precondition(target.x.isFinite && target.y.isFinite && target.z.isFinite, "Camera orbit target must be finite.")
        precondition(minimumRadius.isFinite && minimumRadius > 0, "Camera orbit minimum radius must be finite and positive.")
        precondition(
            maximumRadius.isFinite && maximumRadius >= minimumRadius,
            "Camera orbit maximum radius must be finite and no smaller than its minimum."
        )

        self.target = target
        self.minimumRadius = minimumRadius
        self.maximumRadius = maximumRadius
    }

    mutating func update(world: inout World, deltaTime: Float) {
        let yawDelta = finiteOrZero(
            world.input.actions.cameraOrbitYawDelta
        )
        let zoomDelta = finiteOrZero(
            world.input.actions.cameraZoomDelta
        )
        guard yawDelta != 0 || zoomDelta != 0 else {
            return
        }

        let currentCamera = world.camera
        let offset = currentCamera.position - target
        guard offset.x.isFinite,
              offset.y.isFinite,
              offset.z.isFinite else {
            return
        }

        let horizontalRadius = hypotf(offset.x, offset.z)
        let currentYaw = atan2f(offset.x, offset.z)
        guard horizontalRadius.isFinite, currentYaw.isFinite else {
            return
        }

        let seededRadius = clampedRadius(horizontalRadius)
        let yawCandidate = currentYaw + yawDelta
        let nextYaw = yawCandidate.isFinite
            ? remainderf(yawCandidate, 2 * .pi)
            : currentYaw
        let radiusCandidate = seededRadius - zoomDelta
        let nextRadius = radiusCandidate.isFinite
            ? clampedRadius(radiusCandidate)
            : seededRadius

        guard nextYaw != currentYaw || nextRadius != seededRadius else {
            return
        }

        let nextPosition = target + SIMD3<Float>(
            sinf(nextYaw) * nextRadius,
            offset.y,
            cosf(nextYaw) * nextRadius
        )
        guard nextPosition.x.isFinite,
              nextPosition.y.isFinite,
              nextPosition.z.isFinite else {
            return
        }

        let nextCamera = Camera.lookingAt(
            target,
            from: nextPosition,
            projection: currentCamera.projection
        )
        guard nextCamera.supportsViewTransform else {
            return
        }

        world.camera = nextCamera
    }

    private func clampedRadius(_ radius: Float) -> Float {
        min(maximumRadius, max(minimumRadius, radius))
    }

    private func finiteOrZero(_ value: Float) -> Float {
        value.isFinite ? value : 0
    }
}
