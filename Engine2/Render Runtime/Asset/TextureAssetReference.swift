import Foundation

/// Packaged source texture that a Render Runtime can decode privately.
///
/// Game Content selects the exact file and its transfer-function
/// interpretation. The value contains no decoded pixels, Metal texture, or
/// backend lifetime state.
nonisolated struct TextureAssetReference: Equatable, Hashable, Sendable {
    /// Exact package-qualified source URL selected by Game Content.
    let resourceURL: URL

    /// Transfer-function policy applied while decoding the source channels.
    let interpretation: TextureAssetInterpretation

    init(resourceURL: URL, interpretation: TextureAssetInterpretation) {
        precondition(resourceURL.isFileURL, "A packaged texture resource must use a file URL.")
        precondition(!resourceURL.lastPathComponent.isEmpty, "A texture resource URL must name a file.")

        self.resourceURL = resourceURL
        self.interpretation = interpretation
    }
}
