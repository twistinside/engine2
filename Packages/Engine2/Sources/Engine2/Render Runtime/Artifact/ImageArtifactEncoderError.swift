/// Failures while preparing or deriving an encoded artifact from completed pixels.
///
/// Every case is local to CPU-side artifact construction. Retrying with the
/// same render result does not advance Simulation, submit GPU work, or rerender.
public nonisolated enum ImageArtifactEncoderError: Error, Equatable, Sendable {
    /// Encoder construction could not resolve the required standard sRGB color space.
    case couldNotCreateSRGBColorSpace

    /// Core Graphics could not expose the detached source bytes as image data.
    case couldNotCreateDataProvider

    /// Core Graphics rejected the validated source layout as an image.
    case couldNotCreateImage

    /// Image I/O could not create the requested destination in mutable data.
    case couldNotCreateDestination

    /// Image I/O accepted the image but failed to finish the encoded payload.
    case destinationFinalizationFailed
}
