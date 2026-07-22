/// Terminal queue feedback outcomes for a Render submission attempt.
enum GPUFrameResult: String, Codable, CaseIterable, Sendable {
    case completed
    case failed
    case notSubmitted
}
