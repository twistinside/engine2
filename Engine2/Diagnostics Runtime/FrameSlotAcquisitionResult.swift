/// Closed outcomes for a nonblocking reusable Render frame-slot acquisition.
enum FrameSlotAcquisitionResult: String, Codable, CaseIterable, Sendable {
    case acquired
    case unavailable
}
