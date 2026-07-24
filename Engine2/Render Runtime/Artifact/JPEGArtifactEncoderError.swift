/// Failures while deriving a JPEG artifact from completed offscreen pixels.
///
/// Every case is local to CPU-side artifact construction. Retrying with the
/// same render result does not advance Simulation, submit GPU work, or rerender.
nonisolated enum JPEGArtifactEncoderError: Error, Equatable, Sendable {
    /// The platform could not provide the required standard sRGB color space.
    case couldNotCreateSRGBColorSpace

    /// Core Graphics could not expose the detached source bytes as image data.
    case couldNotCreateDataProvider

    /// Core Graphics rejected the validated source layout as an image.
    case couldNotCreateImage

    /// Image I/O could not create a JPEG destination backed by mutable data.
    case couldNotCreateDestination

    /// Image I/O accepted the image but failed to finish the JPEG payload.
    case destinationFinalizationFailed
}
