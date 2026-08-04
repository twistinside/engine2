/// Selects the camera used to render one recorded presentation snapshot.
///
/// A Simulation-camera frame follows the recorded snapshot with one stable
/// trace-level viewpoint identity. An explicit frame retains an independently
/// identified and revised camera.
nonisolated enum RenderTraceFrameProjection: Codable, Equatable, Sendable {
    case simulationCamera
    case explicit(RenderViewpoint)

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(Kind.self, forKey: .kind) {
        case .simulationCamera:
            self = .simulationCamera

        case .explicit:
            let record = try container.decode(
                RenderTraceViewpointRecord.self,
                forKey: .viewpoint
            )
            self = .explicit(record.value)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .simulationCamera:
            try container.encode(Kind.simulationCamera, forKey: .kind)

        case let .explicit(viewpoint):
            try container.encode(Kind.explicit, forKey: .kind)
            try container.encode(
                RenderTraceViewpointRecord(viewpoint),
                forKey: .viewpoint
            )
        }
    }

    private enum Kind: String, Codable {
        case simulationCamera
        case explicit
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case viewpoint
    }
}
