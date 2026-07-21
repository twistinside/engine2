/// Closed terminal outcomes for one Render Runtime CPU callback.
enum RenderFrameCPUResult: String, Codable, CaseIterable, Sendable {
    case terminalError
    case materialResolutionFailed
    case missingDrawable
    case invalidDrawableSize
    case targetPreparationFailed
    case encodingFailed
    case abandonedAfterError
    case submitted
}
