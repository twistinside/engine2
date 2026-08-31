import Foundation
import simd

/// Applies semantic orbit and zoom commands to the authoritative Simulation camera.
///
/// The system derives orbit state from `World.camera` on every meaningful tick
/// rather than retaining a second camera state. World replacement and authored
/// cameras therefore remain authoritative. The configured axis preserves the
/// content's axial offset while orbit and zoom operate in its perpendicular
/// plane; pause policy freezes both mutation and presentation publication.
struct SCameraInput: PSystem {
    let target: SIMD3<Float>
    let orbitAxis: SIMD3<Float>
    let minimumRadius: Float
    let maximumRadius: Float

    init(
        target: SIMD3<Float>,
        orbitAxis: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        minimumRadius: Float,
        maximumRadius: Float
    ) {
        precondition(target.isFinite, "Camera orbit target must be finite.")
        let orbitAxisLength = simd_length(orbitAxis)
        precondition(
            orbitAxis.isFinite && orbitAxisLength.isFinite && orbitAxisLength > 0,
            "Camera orbit axis must be finite and nonzero."
        )
        precondition(minimumRadius.isFinite && minimumRadius > 0, "Camera orbit minimum radius must be finite and positive.")
        precondition(
            maximumRadius.isFinite && maximumRadius >= minimumRadius,
            "Camera orbit maximum radius must be finite and no smaller than its minimum."
        )

        self.target = target
        self.orbitAxis = orbitAxis / orbitAxisLength
        self.minimumRadius = minimumRadius
        self.maximumRadius = maximumRadius
    }

    mutating func update(world: inout World, deltaTime: Double) {
        let yawDelta = finiteOrZero(
            world.input.cameraOrbitDelta.x
        )
        let zoomDelta = finiteOrZero(
            world.input.cameraZoomDelta
        )
        guard yawDelta != 0 || zoomDelta != 0 else {
            return
        }

        let orbitTarget = resolvedTarget(in: world)
        let currentCamera = world.camera
        let offset = currentCamera.position - orbitTarget
        guard offset.isFinite else {
            return
        }

        let axialOffset = orbitAxis * simd_dot(offset, orbitAxis)
        let planarOffset = offset - axialOffset
        let orbitRadius = simd_length(planarOffset)
        let referenceDirection = orbitReferenceDirection()
        let tangentDirection = simd_cross(orbitAxis, referenceDirection)
        let currentYaw = atan2f(
            simd_dot(planarOffset, tangentDirection),
            simd_dot(planarOffset, referenceDirection)
        )
        guard orbitRadius.isFinite, currentYaw.isFinite else {
            return
        }

        let seededRadius = clampedRadius(orbitRadius)
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

        let nextPlanarOffset = referenceDirection * (cosf(nextYaw) * nextRadius)
            + tangentDirection * (sinf(nextYaw) * nextRadius)
        let nextPosition = orbitTarget + axialOffset + nextPlanarOffset
        guard nextPosition.isFinite else {
            return
        }

        let nextCamera = Camera.lookingAt(
            orbitTarget,
            from: nextPosition,
            up: orbitAxis,
            projection: currentCamera.projection
        )
        guard nextCamera.supportsViewTransform else {
            return
        }

        world.camera = nextCamera
    }

    private func resolvedTarget(in world: World) -> SIMD3<Float> {
        guard let entity = world.cameraFollowEntityID,
              let position = world.positionComponents[entity]?.position,
              position.isFinite else {
            return target
        }

        let resolvedTarget = position.singlePrecision
        return resolvedTarget.isFinite ? resolvedTarget : target
    }

    private func clampedRadius(_ radius: Float) -> Float {
        min(maximumRadius, max(minimumRadius, radius))
    }

    private func orbitReferenceDirection() -> SIMD3<Float> {
        let preferredReference = SIMD3<Float>(0, 0, 1)
        let fallbackReference = SIMD3<Float>(0, 1, 0)
        let reference = abs(simd_dot(orbitAxis, preferredReference)) < 0.99
            ? preferredReference
            : fallbackReference
        return simd_normalize(reference - orbitAxis * simd_dot(reference, orbitAxis))
    }

    private func finiteOrZero(_ value: Float) -> Float {
        value.isFinite ? value : 0
    }
}
