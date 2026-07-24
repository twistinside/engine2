/// Owns one render-gated offline capture topology without exposing its peers.
///
/// Clients receive the initial exact cursor and one narrow capture capability.
/// The concrete Simulation Runtime, offscreen Render Runtime, and coordinator
/// remain retained behind that boundary, so no second caller can bypass serial
/// capture policy and become an accidental advance authority.
@MainActor
final class OfflineCaptureAssembly {
    /// Cursor from which the first optimistic capture request may advance.
    let initialCursor: SimulationCursor

    private let coordinator: OfflineCaptureCoordinator

    init(
        initialCursor: SimulationCursor,
        coordinator: OfflineCaptureCoordinator
    ) {
        self.initialCursor = initialCursor
        self.coordinator = coordinator
    }

    /// Sole directed workflow capability exposed by this assembly.
    nonisolated var captureTarget: any POfflineCaptureTarget {
        coordinator
    }
}
