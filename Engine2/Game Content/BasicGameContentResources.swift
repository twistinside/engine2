import Foundation

/// Resolves source files owned by Basic Game Content before Runtime construction.
///
/// This is the only Basic Game Content boundary that knows how the current App
/// bundles its source assets. Render receives exact URLs and never searches an
/// application bundle by filename.
nonisolated enum BasicGameContentResources {
    static let ballModelURL = requiredURL(
        resourceName: "Ball",
        resourceExtension: "usdz"
    )

    private static func requiredURL(
        resourceName: String,
        resourceExtension: String
    ) -> URL {
        guard let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: resourceExtension
        ) else {
            preconditionFailure(
                "Basic Game Content is missing \(resourceName).\(resourceExtension)."
            )
        }

        return url
    }
}
