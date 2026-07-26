# Model Mutually Exclusive State with Enums

When several flags and optional payloads describe one mutually exclusive state, represent that state with an enum and
carry case-specific data as associated values. The compiler should make invalid combinations unrepresentable.

Do not combine independent dimensions merely because they belong to one object. Model only the values that must
transition together; keep genuinely orthogonal operation, lifecycle, and cancellation state separate.

## Avoid

```swift
var isExporterPresented = false
private(set) var exportDocument: JPEGArtifactDocument?
private(set) var defaultFilename = "Engine2 Snapshot"
var isFailurePresented = false
private(set) var failureMessage = ""
private(set) var failureAllowsExportRetry = false
```

These properties describe one modal presentation lane, but they permit combinations that have no meaning:

- the exporter can be presented without a document;
- export retry can be allowed without retaining the export;
- the exporter and failure can both be presented;
- a failure can be presented without a meaningful message;
- the filename and document can outlive the state in which they are valid.

Every transition must coordinate several assignments correctly:

```swift
isExporterPresented = false
exportDocument = nil
failureAllowsExportRetry = false
isFailurePresented = false
```

The compiler cannot detect a forgotten assignment or prevent another method from creating an impossible combination.

## Prefer

Define the closed presentation value in its own file. Each case carries exactly the data valid in that state:

```swift
/// Mutually exclusive modal presentation owned by snapshot capture UI.
enum SnapshotCapturePresentation {
    case exporter(document: JPEGArtifactDocument, defaultFilename: String)
    case captureFailure(message: String)
    case exportFailure(message: String, document: JPEGArtifactDocument, defaultFilename: String)
}
```

The view model stores one optional presentation:

```swift
private(set) var presentedModal: SnapshotCapturePresentation?
```

The optional represents whether a modal is presented. The enum represents which modal it is. Associated values ensure
an exporter always owns its document and filename, an export failure retains exactly what retry needs, and a capture
failure cannot accidentally advertise export retry.

Transitions become single assignments:

```swift
let document = JPEGArtifactDocument(artifact: artifact)
let defaultFilename = "Engine2-tick-\(sourceSnapshot.cursor.tick.rawValue)"
presentedModal = .exporter(document: document, defaultFilename: defaultFilename)

presentedModal = .exportFailure(
    message: "The rendered JPEG could not be saved. \(error.localizedDescription)",
    document: document,
    defaultFilename: defaultFilename
)

presentedModal = .captureFailure(message: "Another snapshot capture is already in progress.")

presentedModal = nil
```

Code that handles the state must be exhaustive:

```swift
guard let presentedModal else {
    return
}

switch presentedModal {
case let .exporter(document, defaultFilename):
    presentExporter(document: document, defaultFilename: defaultFilename)
case let .captureFailure(message):
    presentFailure(message, retryDocument: nil)
case let .exportFailure(message, document, defaultFilename):
    presentFailure(message, retryDocument: document, defaultFilename: defaultFilename)
}
```

SwiftUI or another UI framework may require a Boolean binding for presentation. Derive that adapter from the enum at the
view boundary rather than storing another Boolean source of truth. A framework may write `false` before invoking its
completion or cancellation callback; do not clear retained payloads in that binding setter when a later callback still
needs them. Let completion, cancellation, retry, and discard operations own the authoritative transition, or model an
explicit awaiting-result state when the framework requires it.

## Keep Independent State Independent

An enum should encode exclusivity, not force unrelated facts into one combinatorial state machine. In the snapshot
workflow, an in-progress capture, window-presentation activity, and a lifecycle generation protect different concerns
from the modal being shown. They may remain separate:

```swift
private(set) var isCapturing = false
private var isPresentationActive = false
private var presentationGeneration: UInt64 = 0
```

Keep a `Bool` for a genuinely independent binary fact. Use separate enums for orthogonal state dimensions. Introduce one
enum when multiple properties must change together and only a finite set of combinations is valid.
