/// Coordinate origin used to interpret rows in a detached rendered image.
nonisolated enum RenderedImageOrigin: Equatable, Hashable, Sendable {
    /// The first stored row is the image's uppermost row.
    case topLeft
}
