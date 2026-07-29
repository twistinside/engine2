/// Queue-feedback failure from one submitted Metal offscreen render.
///
/// Metal owns the open-ended driver diagnostic, while this focused error keeps
/// the concrete submission workflow's failure domain explicit. The Runtime
/// translates it into a stable `OffscreenRenderFailure` at its public outcome
/// boundary.
nonisolated enum MetalOffscreenSubmissionError: Error, Equatable, Sendable {
    case gpuExecutionFailed(String)

    /// Driver-provided detail preserved for the Runtime boundary translation.
    var backendDescription: String {
        switch self {
        case let .gpuExecutionFailed(description):
            description
        }
    }
}
