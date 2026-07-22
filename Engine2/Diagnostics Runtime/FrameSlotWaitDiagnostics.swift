/// Cost and outcome of probing one reusable Render frame slot.
///
/// The payload retains the stable `FrameSlotWait` trace vocabulary even though
/// the production policy no longer blocks when the slot is unavailable.
struct FrameSlotWaitDiagnostics: Codable, Equatable, Sendable {
    let frameSequence: RenderFrameSequence
    let frameSlot: Int
    let result: FrameSlotAcquisitionResult
    let durationNanoseconds: UInt64
}
