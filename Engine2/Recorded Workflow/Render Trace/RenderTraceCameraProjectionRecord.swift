/// Stable schema-v1 representation of a backend-neutral camera projection.
nonisolated enum RenderTraceCameraProjectionRecord: Codable, Equatable, Sendable {
    case orthographic(height: Float, near: Float, far: Float)
    case perspective(
        verticalFieldOfView: Float,
        near: Float,
        far: Float
    )

    /// Reconstructs the projection after persistence validation succeeds.
    var value: Camera.Projection {
        switch self {
        case let .orthographic(height, near, far):
            .orthographic(height: height, near: near, far: far)

        case let .perspective(verticalFieldOfView, near, far):
            .perspective(
                verticalFieldOfView: verticalFieldOfView,
                near: near,
                far: far
            )
        }
    }

    /// Captures one validated domain projection for durable storage.
    init(_ projection: Camera.Projection) throws(RenderTraceValidationError) {
        switch projection {
        case let .orthographic(height, near, far):
            try self.init(
                kind: .orthographic,
                height: height,
                verticalFieldOfView: nil,
                near: near,
                far: far
            )

        case let .perspective(verticalFieldOfView, near, far):
            try self.init(
                kind: .perspective,
                height: nil,
                verticalFieldOfView: verticalFieldOfView,
                near: near,
                far: far
            )
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            kind: container.decode(Kind.self, forKey: .kind),
            height: container.decodeIfPresent(Float.self, forKey: .height),
            verticalFieldOfView: container.decodeIfPresent(
                Float.self,
                forKey: .verticalFieldOfView
            ),
            near: container.decode(Float.self, forKey: .near),
            far: container.decode(Float.self, forKey: .far)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .orthographic(height, near, far):
            try container.encode(Kind.orthographic, forKey: .kind)
            try container.encode(height, forKey: .height)
            try container.encode(near, forKey: .near)
            try container.encode(far, forKey: .far)

        case let .perspective(verticalFieldOfView, near, far):
            try container.encode(Kind.perspective, forKey: .kind)
            try container.encode(
                verticalFieldOfView,
                forKey: .verticalFieldOfView
            )
            try container.encode(near, forKey: .near)
            try container.encode(far, forKey: .far)
        }
    }

    private init(
        kind: Kind,
        height: Float?,
        verticalFieldOfView: Float?,
        near: Float,
        far: Float
    ) throws(RenderTraceValidationError) {
        guard near.isFinite,
              near > 0,
              far.isFinite,
              far > near else {
            throw .invalidCameraProjection
        }

        switch kind {
        case .orthographic:
            guard let height,
                  height.isFinite,
                  height > 0,
                  verticalFieldOfView == nil else {
                throw .invalidCameraProjection
            }
            self = .orthographic(height: height, near: near, far: far)

        case .perspective:
            guard let verticalFieldOfView,
                  verticalFieldOfView.isFinite,
                  verticalFieldOfView > 0,
                  verticalFieldOfView < .pi,
                  height == nil else {
                throw .invalidCameraProjection
            }
            self = .perspective(
                verticalFieldOfView: verticalFieldOfView,
                near: near,
                far: far
            )
        }
    }

    private enum Kind: String, Codable {
        case orthographic
        case perspective
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case height
        case verticalFieldOfView
        case near
        case far
    }
}
