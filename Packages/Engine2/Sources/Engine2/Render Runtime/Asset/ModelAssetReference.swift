import Foundation

/// Packaged source model that a Render Runtime can resolve privately.
///
/// This value deliberately contains no Model I/O or Metal objects. Game
/// Content can therefore describe an asset without taking ownership of the
/// backend resource created from it.
nonisolated public struct ModelAssetReference: Equatable, Hashable, Sendable {
    /// Exact package-qualified source URL selected by Game Content.
    public let resourceURL: URL

    public let format: ModelAssetFormat

    /// Source name used in diagnostics without discarding package provenance.
    public var resourceName: String {
        resourceURL.deletingPathExtension().lastPathComponent
    }

    public init(resourceURL: URL, format: ModelAssetFormat) {
        precondition(resourceURL.isFileURL, "A packaged model resource must use a file URL.")
        precondition(!resourceURL.lastPathComponent.isEmpty, "A model resource URL must name a file.")

        self.resourceURL = resourceURL
        self.format = format
    }
}
