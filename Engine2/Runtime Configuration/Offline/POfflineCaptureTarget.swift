/// Narrow directed capability for exact advance-render-encode capture work.
///
/// The asynchronous, nonisolated contract lets an App, tool, or future remote
/// coordinator request one bounded workflow without learning which actor owns
/// serialization or gaining direct access to Simulation or Render runtimes.
nonisolated protocol POfflineCaptureTarget: AnyObject, Sendable {
    func capture(_ request: OfflineCaptureRequest) async -> OfflineCaptureOutcome
}
