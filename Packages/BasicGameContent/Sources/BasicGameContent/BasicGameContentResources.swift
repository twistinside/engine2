import Foundation

/// Resolves the packaged source assets required by Basic Game Content.
///
/// Successful package construction guarantees these static resources exist.
/// A missing URL therefore reports a packaging defect before any Runtime
/// attempts to decode or upload the model.
enum BasicGameContentResources {
    static let ballModelURL: URL = {
        guard let url = Bundle.module.url(
            forResource: "Ball",
            withExtension: "usdz"
        ) else {
            preconditionFailure("Basic Game Content is missing Ball.usdz.")
        }

        return url
    }()
}
