import Foundation

/// Packaged source model that a Render Runtime can resolve privately.
///
/// This value deliberately contains no Model I/O or Metal objects. Game
/// Content can therefore describe an asset without taking ownership of the
/// backend resource created from it.
nonisolated struct ModelAssetReference: Equatable, Hashable, Sendable {
    /// Exact package-qualified source URL selected by Game Content.
    let resourceURL: URL

    let format: ModelAssetFormat

    /// Source name used in diagnostics without discarding package provenance.
    var resourceName: String {
        resourceURL.deletingPathExtension().lastPathComponent
    }

    init(resourceURL: URL, format: ModelAssetFormat) {
        precondition(resourceURL.isFileURL, "A packaged model resource must use a file URL.")
        precondition(!resourceURL.lastPathComponent.isEmpty, "A model resource URL must name a file.")
        precondition(
            resourceURL.pathExtension.lowercased() == format.rawValue,
            "A model resource URL must use the declared source format."
        )

        self.resourceURL = resourceURL
        self.format = format
    }
}
