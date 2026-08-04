/// Durable schema-v1 representation of exact offscreen Render settings.
nonisolated struct RenderTraceSettingsRecord: Codable, Equatable, Sendable {
    let width: Int
    let height: Int
    let outputMode: RenderTraceOutputModeRecord
    let exposureMultiplier: Float

    /// Captures one validated settings value for durable storage.
    init(
        _ settings: OffscreenRenderSettings
    ) throws(RenderTraceValidationError) {
        try self.init(
            width: settings.size.width,
            height: settings.size.height,
            outputMode: RenderTraceOutputModeRecord(settings.outputMode),
            exposureMultiplier: settings.exposure.multiplier
        )
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            width: container.decode(Int.self, forKey: .width),
            height: container.decode(Int.self, forKey: .height),
            outputMode: container.decode(
                RenderTraceOutputModeRecord.self,
                forKey: .outputMode
            ),
            exposureMultiplier: container.decode(
                Float.self,
                forKey: .exposureMultiplier
            )
        )
    }

    /// Reconstructs settings after persistence validation succeeds.
    func value() throws(RenderTraceValidationError) -> OffscreenRenderSettings {
        let size: RenderPixelSize
        do {
            size = try RenderPixelSize(width: width, height: height)
        } catch {
            throw .invalidPixelSize(error)
        }

        return OffscreenRenderSettings(
            size: size,
            outputMode: outputMode.value,
            exposure: ManualExposure(multiplier: exposureMultiplier)
        )
    }

    private init(
        width: Int,
        height: Int,
        outputMode: RenderTraceOutputModeRecord,
        exposureMultiplier: Float
    ) throws(RenderTraceValidationError) {
        do {
            _ = try RenderPixelSize(width: width, height: height)
        } catch {
            throw .invalidPixelSize(error)
        }
        guard exposureMultiplier.isFinite, exposureMultiplier >= 0 else {
            throw .invalidExposure
        }

        self.width = width
        self.height = height
        self.outputMode = outputMode
        self.exposureMultiplier = exposureMultiplier
    }

    private enum CodingKeys: String, CodingKey {
        case width
        case height
        case outputMode
        case exposureMultiplier
    }
}
