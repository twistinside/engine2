/// Main-actor back-pressure spent waiting for one reusable frame slot.
struct FrameSlotWaitDiagnostics: Codable, Equatable, Sendable {
    let frameSequence: RenderFrameSequence
    let frameSlot: Int
    let durationNanoseconds: UInt64
}
