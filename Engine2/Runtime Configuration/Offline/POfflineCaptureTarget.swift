/// Narrow directed capability for exact serial capture work.
///
/// The asynchronous, nonisolated contract lets an App, tool, or future remote
/// coordinator either advance then capture or recapture the retained current
/// presentation. Callers do not learn which actor owns serialization and gain
/// no direct access to Simulation, its latest publication, or Render runtimes.
nonisolated protocol POfflineCaptureTarget: AnyObject, Sendable {
    func capture(_ request: OfflineCaptureRequest) async -> OfflineCaptureOutcome

    func captureCurrent(
        _ request: OfflineCurrentCaptureRequest
    ) async -> OfflineCurrentCaptureOutcome
}
