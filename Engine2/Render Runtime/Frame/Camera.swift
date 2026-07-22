import Foundation
import simd

/// Abstract render camera state owned by the engine, not by a specific backend.
nonisolated struct Camera: Sendable {
    /// Backend-neutral projection parameters used to construct a clip-space matrix.
    ///
    /// Associated values are expressed in world units and radians. Both
    /// projection cases describe `near` and `far` as positive distances along
    /// the camera's local forward axis, which points down view-space `-Z`.
    /// Camera initialization validates the dimensions and clipping-plane
    /// ordering so render backends can consume a well-formed projection.
    nonisolated enum Projection: Equatable, Sendable {
        case orthographic(height: Float, near: Float, far: Float)
        case perspective(verticalFieldOfView: Float, near: Float, far: Float)
    }

    var position: SIMD3<Float>
    var rotation: simd_quatf
    var projection: Projection

    init(
        position: SIMD3<Float> = SIMD3<Float>(0, 0, 8),
        rotation: simd_quatf = Transform.identityRotation,
        projection: Projection = .perspective(
            verticalFieldOfView: .pi / 3,
            near: 0.1,
            far: 100
        )
    ) {
        Self.validate(projection)

        self.position = position
        self.rotation = rotation
        self.projection = projection
    }

    init(
        position: SIMD3<Float>,
        rotation: simd_quatf = Transform.identityRotation,
        orthographicHeight: Float,
        nearPlane: Float = 0.1,
        farPlane: Float = 100
    ) {
        self.init(
            position: position,
            rotation: rotation,
            projection: .orthographic(
                height: orthographicHeight,
                near: nearPlane,
                far: farPlane
            )
        )
    }

    /// Builds a camera placed at `position` and aimed at a target point.
    static func lookingAt(
        _ target: SIMD3<Float>,
        from position: SIMD3<Float>,
        up: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        projection: Projection = .perspective(
            verticalFieldOfView: .pi / 3,
            near: 0.1,
            far: 100
        )
    ) -> Camera {
        Camera(
            position: position,
            rotation: rotationLookingAt(target, from: position, up: up),
            projection: projection
        )
    }

    /// Converts world-space positions into the camera's local view space.
    var viewMatrix: simd_float4x4 {
        .rotation(rotation.inverse) * .translation(-position)
    }

    /// Whether this camera can construct a finite world-to-view transform.
    ///
    /// Camera values are copied across the Simulation-to-Render snapshot
    /// boundary. Render projection checks this invariant so malformed mutable
    /// simulation state produces no draw instances instead of NaN view-space
    /// positions and normal matrices.
    var supportsViewTransform: Bool {
        let positionIsFinite = position.x.isFinite
            && position.y.isFinite
            && position.z.isFinite
        let rotationVector = rotation.vector
        let rotationLengthSquared = simd_length_squared(rotationVector)
        let rotationIsFiniteAndNonzero = rotationVector.x.isFinite
            && rotationVector.y.isFinite
            && rotationVector.z.isFinite
            && rotationVector.w.isFinite
            && rotationLengthSquared.isFinite
            && rotationLengthSquared > 0

        guard positionIsFinite && rotationIsFiniteAndNonzero else {
            return false
        }

        // Finite inputs can still overflow when a very large translation is
        // rotated. Validate the matrix that rendering will actually consume,
        // not only the values used to build it.
        return viewMatrix.hasFiniteElements
    }

    /// Builds a Metal clip-space projection for the current drawable shape.
    func projectionMatrix(aspectRatio: Float) -> simd_float4x4 {
        let safeAspectRatio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1

        switch projection {
        case let .orthographic(height, near, far):
            let halfHeight = height / 2
            let halfWidth = halfHeight * safeAspectRatio

            return .orthographic(
                left: -halfWidth,
                right: halfWidth,
                bottom: -halfHeight,
                top: halfHeight,
                near: near,
                far: far
            )

        case let .perspective(verticalFieldOfView, near, far):
            return .perspective(
                verticalFieldOfView: verticalFieldOfView,
                aspectRatio: safeAspectRatio,
                near: near,
                far: far
            )
        }
    }

    func viewProjectionMatrix(aspectRatio: Float) -> simd_float4x4 {
        projectionMatrix(aspectRatio: aspectRatio) * viewMatrix
    }

    private static func rotationLookingAt(
        _ target: SIMD3<Float>,
        from position: SIMD3<Float>,
        up: SIMD3<Float>
    ) -> simd_quatf {
        let forward = simd_normalize(target - position)
        let right = simd_normalize(simd_cross(forward, up))
        let correctedUp = simd_cross(right, forward)
        let cameraToWorld = simd_float3x3(
            columns: (
                right,
                correctedUp,
                -forward
            )
        )

        return simd_quatf(cameraToWorld)
    }

    private static func validate(_ projection: Projection) {
        switch projection {
        case let .orthographic(height, near, far):
            precondition(
                height.isFinite && height > 0,
                "Camera orthographic height must be finite and positive."
            )
            precondition(
                near.isFinite && near > 0,
                "Camera orthographic near plane must be finite and positive."
            )
            precondition(
                far.isFinite && far > near,
                "Camera orthographic far plane must be finite and greater than the near plane."
            )

        case let .perspective(verticalFieldOfView, near, far):
            precondition(
                verticalFieldOfView.isFinite && verticalFieldOfView > 0,
                "Camera field of view must be finite and positive."
            )
            precondition(
                verticalFieldOfView < .pi,
                "Camera field of view must be less than pi radians."
            )
            precondition(
                near.isFinite && near > 0,
                "Camera perspective near plane must be finite and positive."
            )
            precondition(
                far.isFinite && far > near,
                "Camera perspective far plane must be finite and greater than the near plane."
            )
        }
    }
}

nonisolated extension Camera: Equatable {
    static func == (lhs: Camera, rhs: Camera) -> Bool {
        lhs.position == rhs.position &&
        lhs.rotation.vector == rhs.rotation.vector &&
        lhs.projection == rhs.projection
    }
}

nonisolated private extension simd_float4x4 {
    static func orthographic(
        left: Float,
        right: Float,
        bottom: Float,
        top: Float,
        near: Float,
        far: Float
    ) -> simd_float4x4 {
        let width = right - left
        let height = top - bottom
        let depth = far - near

        return simd_float4x4(
            columns: (
                SIMD4<Float>(2 / width, 0, 0, 0),
                SIMD4<Float>(0, 2 / height, 0, 0),
                // Camera-forward points have negative view-space Z. Negating
                // that coordinate makes orthographic near/far values use the
                // same positive-distance meaning as perspective projection.
                SIMD4<Float>(0, 0, -1 / depth, 0),
                SIMD4<Float>(
                    -(right + left) / width,
                    -(top + bottom) / height,
                    -near / depth,
                    1
                )
            )
        )
    }

    static func perspective(
        verticalFieldOfView: Float,
        aspectRatio: Float,
        near: Float,
        far: Float
    ) -> simd_float4x4 {
        let yScale = 1 / tanf(verticalFieldOfView / 2)
        let xScale = yScale / aspectRatio
        let zScale = far / (near - far)
        let zTranslation = near * far / (near - far)

        return simd_float4x4(
            columns: (
                SIMD4<Float>(xScale, 0, 0, 0),
                SIMD4<Float>(0, yScale, 0, 0),
                SIMD4<Float>(0, 0, zScale, -1),
                SIMD4<Float>(0, 0, zTranslation, 0)
            )
        )
    }
}
