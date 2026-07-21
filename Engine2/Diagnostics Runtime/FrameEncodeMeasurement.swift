import Foundation
import OSLog

/// Opaque start state that lets Render measure nonescaping Metal work in place.
struct FrameEncodeMeasurement {
    let start: SuspendingClock.Instant
    let signpostState: OSSignpostIntervalState
}
