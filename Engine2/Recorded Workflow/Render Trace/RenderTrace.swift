import Foundation

/// Versioned renderer-input trace that requires no live Simulation Runtime.
///
/// The trace owns ordered immutable presentations, camera choices, and output
/// settings. Consumers can therefore benchmark or inspect Render independently
/// while preserving the Simulation provenance of every frame.
nonisolated struct RenderTrace: Codable, Equatable, Sendable {
    static let currentSchemaVersion = RenderTraceSchemaVersion.version1

    let header: RenderTraceHeader
    let frames: [RenderTraceFrame]

    /// Exact renderer-domain inputs in durable frame order.
    var renderInputs: [RenderTraceRenderInput] {
        frames.map {
            $0.renderInput(
                simulationCameraViewpointID:
                    header.simulationCameraViewpointID
            )
        }
    }

    /// Constructs a validated trace from already formed frames.
    init(
        header: RenderTraceHeader,
        frames: [RenderTraceFrame]
    ) throws(RenderTraceValidationError) {
        guard header.schemaVersion == Self.currentSchemaVersion else {
            throw .unsupportedSchemaVersion(
                header.schemaVersion.rawValue
            )
        }
        guard frames.isEmpty == false else {
            throw .emptyFrames
        }

        try Self.validateFrameOrder(frames)

        self.header = header
        self.frames = frames
    }

    /// Records ordered completed presentations that follow their Simulation camera.
    init(
        traceID: UUID = UUID(),
        contentIdentifier: RecordingContentIdentifier,
        simulationCameraViewpointID: RenderViewpointID,
        presentationSnapshots: [SimulationPresentationSnapshot],
        settings: OffscreenRenderSettings,
        clearColor: RenderTraceClearColor = .opaqueBlack
    ) throws(RenderTraceValidationError) {
        var frames: [RenderTraceFrame] = []
        frames.reserveCapacity(presentationSnapshots.count)
        for (index, snapshot) in presentationSnapshots.enumerated() {
            frames.append(
                try RenderTraceFrame(
                    sequence: UInt64(index),
                    presentationSnapshot: snapshot,
                    projection: .simulationCamera,
                    settings: settings,
                    clearColor: clearColor
                )
            )
        }
        let header = RenderTraceHeader(
            schemaVersion: Self.currentSchemaVersion,
            traceID: traceID,
            contentIdentifier: contentIdentifier,
            simulationCameraViewpointID: simulationCameraViewpointID
        )

        try self.init(header: header, frames: frames)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let header = try container.decode(
            RenderTraceHeader.self,
            forKey: .header
        )
        guard header.schemaVersion == Self.currentSchemaVersion else {
            throw RenderTraceValidationError.unsupportedSchemaVersion(
                header.schemaVersion.rawValue
            )
        }
        let frames = try container.decode(
            [RenderTraceFrame].self,
            forKey: .frames
        )

        try self.init(
            header: header,
            frames: frames
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(header, forKey: .header)
        try container.encode(frames, forKey: .frames)
    }

    private static func validateFrameOrder(
        _ frames: [RenderTraceFrame]
    ) throws(RenderTraceValidationError) {
        var previousSequence = frames[0].sequence
        for frame in frames.dropFirst() {
            guard frame.sequence > previousSequence else {
                throw .nonincreasingFrameSequence(
                    previous: previousSequence,
                    current: frame.sequence
                )
            }
            previousSequence = frame.sequence
        }
    }

    private enum CodingKeys: String, CodingKey {
        case header
        case frames
    }
}
