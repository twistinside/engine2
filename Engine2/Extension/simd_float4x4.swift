import Foundation
import simd

nonisolated extension simd_float4x4 {
    /// Whether every scalar in this matrix is finite.
    ///
    /// Checking the constructed matrix catches arithmetic overflow that finite
    /// transform inputs alone cannot exclude.
    var hasFiniteElements: Bool {
        [columns.0, columns.1, columns.2, columns.3].allSatisfy { column in
            column.x.isFinite
                && column.y.isFinite
                && column.z.isFinite
                && column.w.isFinite
        }
    }

    static var identity: simd_float4x4 {
        matrix_identity_float4x4
    }

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

    static func rotation(_ rotation: simd_quatf) -> simd_float4x4 {
        let q = simd_normalize(rotation.vector)
        let x = q.x
        let y = q.y
        let z = q.z
        let w = q.w

        return simd_float4x4(
            columns: (
                SIMD4<Float>(
                    1 - 2 * y * y - 2 * z * z,
                    2 * x * y + 2 * w * z,
                    2 * x * z - 2 * w * y,
                    0
                ),
                SIMD4<Float>(
                    2 * x * y - 2 * w * z,
                    1 - 2 * x * x - 2 * z * z,
                    2 * y * z + 2 * w * x,
                    0
                ),
                SIMD4<Float>(
                    2 * x * z + 2 * w * y,
                    2 * y * z - 2 * w * x,
                    1 - 2 * x * x - 2 * y * y,
                    0
                ),
                SIMD4<Float>(0, 0, 0, 1)
            )
        )
    }

    static func scale(_ scale: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(
            columns: (
                SIMD4<Float>(scale.x, 0, 0, 0),
                SIMD4<Float>(0, scale.y, 0, 0),
                SIMD4<Float>(0, 0, scale.z, 0),
                SIMD4<Float>(0, 0, 0, 1)
            )
        )
    }

    static func translation(_ translation: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(
            columns: (
                SIMD4<Float>(1, 0, 0, 0),
                SIMD4<Float>(0, 1, 0, 0),
                SIMD4<Float>(0, 0, 1, 0),
                SIMD4<Float>(translation.x, translation.y, translation.z, 1)
            )
        )
    }
}
