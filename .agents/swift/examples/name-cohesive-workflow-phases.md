# Name Cohesive Workflow Phases

A coordinating method that owns several substantial operations should read
as the ordered domain workflow. Move a cohesive phase to a private instance
method when its implementation detail obscures that workflow and its contract
has a name that clarifies the boundary.

Line count can reveal a problem, but it does not define one. Extract methods to
name responsibilities, preserve ordering, and expose data flow. Do not divide
code merely to make the original method shorter.

## Avoid One Method That Hides the Workflow

This encoder performs four distinct operations in one body: it constructs a
source image, projects the caller's encoding choice into Image I/O
configuration, writes encoded bytes, and forms an artifact that preserves the
render provenance.

This abbreviated example omits the production comments that explain bitmap
interpretation and the mutable CFData sink. Those details remain important,
but they do not need to occupy the coordinating method.

```swift
@concurrent
func encode(
    _ result: OffscreenRenderResult,
    as encoding: ImageArtifactEncoding
) async throws(ImageArtifactEncoderError) -> RenderedImageArtifact {
    guard let provider = CGDataProvider(data: result.image.bytes as CFData) else {
        throw .couldNotCreateDataProvider
    }

    let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
        CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
    )
    guard let sourceImage = CGImage(
        width: result.image.size.width,
        height: result.image.size.height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: result.image.bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ) else {
        throw .couldNotCreateImage
    }

    let destinationType: UTType
    let destinationProperties: CFDictionary?
    switch encoding {
    case let .jpeg(quality):
        destinationType = .jpeg
        destinationProperties = [
            kCGImageDestinationLossyCompressionQuality: quality.value
        ] as CFDictionary
    case .png:
        destinationType = .png
        destinationProperties = nil
    }

    let destinationData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        destinationData as CFMutableData,
        destinationType.identifier as CFString,
        1,
        nil
    ) else {
        throw .couldNotCreateDestination
    }

    CGImageDestinationAddImage(destination, sourceImage, destinationProperties)
    guard CGImageDestinationFinalize(destination) else {
        throw .destinationFinalizationFailed
    }

    let encodedData = Data(
        bytes: destinationData.bytes,
        count: destinationData.length
    )
    return RenderedImageArtifact(
        encoding: encoding,
        encodedData: encodedData,
        sourceRequestID: result.requestID,
        sourceCursor: result.sourceCursor,
        viewpoint: result.viewpoint,
        renderSettings: result.settings
    )
}
```

The code is sequential, but the reader must discover where each phase begins,
which failures belong to it, and what values cross into the next phase.

## Prefer a Boundary That States the Domain Workflow

Keep provenance assembly at the boundary and name the phases that hide
framework mechanics:

```swift
@concurrent
func encode(
    _ result: OffscreenRenderResult,
    as encoding: ImageArtifactEncoding
) async throws(ImageArtifactEncoderError) -> RenderedImageArtifact {
    let sourceImage = try makeSourceImage(from: result.image)
    let destinationConfiguration = destinationConfiguration(for: encoding)
    let encodedData = try encodeImage(
        sourceImage,
        as: destinationConfiguration.type,
        properties: destinationConfiguration.properties
    )
    return RenderedImageArtifact(
        encoding: encoding,
        encodedData: encodedData,
        sourceRequestID: result.requestID,
        sourceCursor: result.sourceCursor,
        viewpoint: result.viewpoint,
        renderSettings: result.settings
    )
}
```

The boundary now states the complete workflow:

1. Construct the source image.
2. Project the selected encoding into Image I/O configuration.
3. Encode detached bytes.
4. Form the artifact with its original provenance.

The helpers remain private instance methods because they implement one
encoder's workflow whether or not each implementation currently reads state.
`makeSourceImage(from:)` also uses the encoder's retained color space:

| Private method | Cohesive responsibility |
| --- | --- |
| `makeSourceImage(from:)` | Interpret the source bytes and return one validated Core Graphics image. |
| `destinationConfiguration(for:)` | Project the encoding choice into a destination type and format properties. |
| `encodeImage(_:as:properties:)` | Write the configured image and return detached immutable bytes. |

Each helper returns one useful successful value directly. The fallible phases
propagate `ImageArtifactEncoderError` through typed throws. Their names state
the result or operation without requiring the reader to inspect their bodies.

## Preserve the Important Story

Keep a guard, state transition, or comment in the coordinating method when its
position defines the contract. Extraction must not hide:

- admission before mutation;
- cancellation before or after an irreversible boundary;
- state ownership transfer;
- isolation or executor boundaries;
- committed bookkeeping before lifecycle exit;
- exhaustive handling of a closed outcome;
- publication before a result becomes observable.

Keep validation inside an extracted phase when it is intrinsic to the value
that phase returns. `makeSourceImage(from:)`, for example, owns the provider and
image-construction guards. They do not order one phase relative to another.

Name side effects directly. Prefer `publishCompletedAdvanceResult` when a
method publishes state and returns a result. Do not call it `makeResult`, which
suggests pure construction. Prefer `performTrackedAdvance` when a method owns
quiescence bookkeeping around an asynchronous request. Do not call it
`submit`, which hides the awaited completion and tracking.

Avoid names that remain generic at the call site, such as `helper`, `doWork`,
or numbered phase names. Qualify broad verbs such as `process` or `handle` with
the exact domain event or result, or choose a more precise verb. The complete
name should tell the reader what the phase produces or changes.

## Keep Small Operations Inline

Do not extract a helper when:

- its name only restates one expression or initializer;
- one ordinary `guard` or `if` keeps validation beside the value it protects;
- the helper introduces an optional, tuple, or result only to disguise local
  control flow rather than carry cohesive domain data;
- splitting an exhaustive switch makes its coverage harder to verify;
- the caller becomes shorter but the complete behavior becomes harder to
  understand.

Within the encoder, keep bitmap interpretation with `makeSourceImage(from:)`
and the final immutable copy with `encodeImage(_:as:properties:)`. Separate
`makeBitmapInfo()` or `copyDestinationData()` helpers would restate local
mechanics rather than name new workflow phases.

Use [Prefer Inline Validation Over One-Use Helpers](prefer-inline-validation-over-one-use-helpers.md)
for simple calculations and checks. Use
[Prefer Throws for Internal Failure Propagation](prefer-throws-for-internal-failures.md)
when an extracted phase can return one successful value or throw.
