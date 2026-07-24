import Foundation
import simd
import Testing
import UniformTypeIdentifiers
@testable import Engine2

struct SnapshotCaptureViewModelTests {
    @Test @MainActor
    func defaultRenderSizeUsesNamedUHD4KPreset() {
        #expect(SnapshotCaptureViewModel.defaultRenderSize == .uhd4K)
        #expect(SnapshotCaptureViewModel.defaultRenderSize.width == 3_840)
        #expect(SnapshotCaptureViewModel.defaultRenderSize.height == 2_160)
    }

    @Test @MainActor
    func completedCapturePresentsExactJPEGDocumentAndTickFilename() async throws {
        let size = try RenderPixelSize(width: 8, height: 6)
        let (snapshot, artifact) = try Self.fixture(size: size, tick: 42)
        let target = StubRealtimeSnapshotCaptureTarget(
            outcome: .completed(
                sourceSnapshot: snapshot,
                artifact: artifact
            )
        )
        let model = SnapshotCaptureViewModel(
            captureTarget: target,
            renderSize: size
        )
        model.activatePresentation()

        await model.capture(outputMode: .viewSpaceNormals)

        #expect(model.isCapturing == false)
        #expect(model.isExporterPresented)
        #expect(model.exportDocument?.encodedData == artifact.encodedData)
        #expect(model.defaultFilename == "Engine2-tick-42")

        let request = try #require(target.requests.first)
        #expect(request.renderSettings.size == size)
        #expect(request.renderSettings.outputMode == .viewSpaceNormals)
        #expect(request.jpegSettings.quality == .maximum)

        model.exportCancelled()
        #expect(model.exportDocument == nil)
    }

    @Test @MainActor
    func unavailableRendererSurfacesFailureWithoutPresentingExporter() async {
        let model = SnapshotCaptureViewModel(
            unavailableReason: "Synthetic Metal initialization failure."
        )
        model.activatePresentation()

        await model.capture(outputMode: .surface)

        #expect(model.isCapturing == false)
        #expect(model.isExporterPresented == false)
        #expect(model.exportDocument == nil)
        #expect(model.isFailurePresented)
        #expect(
            model.failureMessage
                == "Synthetic Metal initialization failure."
        )
    }

    @Test @MainActor
    func inactiveAndOverlappingCaptureRequestsDoNotReachTheTarget() async throws {
        let size = try RenderPixelSize(width: 8, height: 6)
        let (snapshot, artifact) = try Self.fixture(size: size, tick: 17)
        let inactiveTarget = StubRealtimeSnapshotCaptureTarget(
            outcome: .completed(
                sourceSnapshot: snapshot,
                artifact: artifact
            )
        )
        let inactiveModel = SnapshotCaptureViewModel(
            captureTarget: inactiveTarget,
            renderSize: size
        )

        await inactiveModel.capture(outputMode: .surface)

        #expect(inactiveTarget.requests.isEmpty)
        #expect(inactiveModel.isCapturing == false)
        #expect(inactiveModel.isExporterPresented == false)

        let suspendedTarget = SuspendedRealtimeSnapshotCaptureTarget()
        let activeModel = SnapshotCaptureViewModel(
            captureTarget: suspendedTarget,
            renderSize: size
        )
        activeModel.activatePresentation()
        let firstCapture = Task {
            await activeModel.capture(outputMode: .surface)
        }
        await suspendedTarget.waitForRequest()
        #expect(activeModel.isCapturing)

        await activeModel.capture(outputMode: .viewSpaceNormals)

        #expect(suspendedTarget.requests.count == 1)
        suspendedTarget.complete(.cancelledBeforeRender)
        await firstCapture.value
    }

    @Test @MainActor
    func failedSaveRetainsExactDocumentForRetryWithoutRecapturing() async throws {
        let size = try RenderPixelSize(width: 8, height: 6)
        let (snapshot, artifact) = try Self.fixture(size: size, tick: 73)
        let target = StubRealtimeSnapshotCaptureTarget(
            outcome: .completed(
                sourceSnapshot: snapshot,
                artifact: artifact
            )
        )
        let model = SnapshotCaptureViewModel(
            captureTarget: target,
            renderSize: size
        )
        model.activatePresentation()
        await model.capture(outputMode: .surface)
        let originalDocument = try #require(model.exportDocument)

        model.exportCompleted(.failure(SyntheticSaveError()))

        #expect(model.isExporterPresented == false)
        #expect(model.exportDocument == originalDocument)
        #expect(model.failureAllowsExportRetry)
        #expect(model.isFailurePresented)
        #expect(model.failureMessage.contains("Synthetic save failure"))
        #expect(target.requests.count == 1)

        model.retryExport()

        #expect(model.isExporterPresented)
        #expect(model.exportDocument == originalDocument)
        #expect(model.failureAllowsExportRetry == false)
        #expect(model.isFailurePresented == false)
        #expect(target.requests.count == 1)

        model.exportCompleted(
            .success(URL(fileURLWithPath: "/tmp/Engine2-tick-73.jpeg"))
        )

        #expect(model.isExporterPresented == false)
        #expect(model.exportDocument == nil)
        #expect(target.requests.count == 1)
    }

    @Test @MainActor
    func disappearingPresentationIgnoresLateCaptureCompletion() async throws {
        let size = try RenderPixelSize(width: 8, height: 6)
        let (snapshot, artifact) = try Self.fixture(size: size, tick: 91)
        let target = SuspendedRealtimeSnapshotCaptureTarget()
        let model = SnapshotCaptureViewModel(
            captureTarget: target,
            renderSize: size
        )
        model.activatePresentation()

        let capture = Task {
            await model.capture(outputMode: .surface)
        }
        await target.waitForRequest()

        model.deactivatePresentation()
        capture.cancel()
        target.complete(
            .completed(
                sourceSnapshot: snapshot,
                artifact: artifact
            )
        )
        await capture.value

        #expect(model.isCapturing == false)
        #expect(model.isExporterPresented == false)
        #expect(model.exportDocument == nil)
    }

    @Test @MainActor
    func captureTerminalMessagesCoverEveryNonSuccessOutcome() async throws {
        let size = try RenderPixelSize(width: 8, height: 6)
        let (snapshot, artifact) = try Self.fixture(size: size, tick: 101)
        let rawResult = try Self.renderResult(
            artifact: artifact,
            size: size
        )
        let rejectionLimits = OffscreenRenderLimits(
            maxDimension: 4,
            maxPixelCount: 16
        )
        let renderFailure = OffscreenRenderFailure(
            stage: .gpuExecution,
            backendDescription: "Synthetic backend failure."
        )
        let wrongRequestID = OffscreenRenderRequestID()
        let scenarios: [
            (
                outcome: RealtimeSnapshotCaptureOutcome,
                expectedMessage: String
            )
        ] = [
            (
                .connectionBusy,
                "Another snapshot capture is already in progress."
            ),
            (
                .cancelledBeforeRender,
                "Snapshot capture was cancelled before rendering."
            ),
            (
                .renderRejected(
                    sourceSnapshot: snapshot,
                    rejection: .runtimeBusy
                ),
                "The offline renderer is busy with another request."
            ),
            (
                .renderRejected(
                    sourceSnapshot: snapshot,
                    rejection: .cancelledBeforeSubmission
                ),
                "Snapshot capture was cancelled before GPU submission."
            ),
            (
                .renderRejected(
                    sourceSnapshot: snapshot,
                    rejection: .invalidViewpoint
                ),
                "The current screen viewpoint cannot be rendered offscreen."
            ),
            (
                .renderRejected(
                    sourceSnapshot: snapshot,
                    rejection: .invalidPresentation(
                        .invalidSelectedCamera
                    )
                ),
                "The selected Simulation snapshot contains invalid "
                    + "presentation data."
            ),
            (
                .renderRejected(
                    sourceSnapshot: snapshot,
                    rejection: .exceedsLimits(
                        requested: size,
                        limits: rejectionLimits
                    )
                ),
                "The requested 8×6 image exceeds the offline limit of "
                    + "4 pixels per side and 16 total pixels."
            ),
            (
                .renderRejected(
                    sourceSnapshot: snapshot,
                    rejection: .instanceLimitExceeded(
                        requested: 257,
                        maximum: 256
                    )
                ),
                "The selected snapshot contains 257 render instances; "
                    + "the offline renderer supports 256."
            ),
            (
                .renderFailed(
                    sourceSnapshot: snapshot,
                    failure: renderFailure
                ),
                "The offline renderer failed during gpuExecution. "
                    + "Synthetic backend failure."
            ),
            (
                .renderCancellationRequestIDMismatch(
                    sourceSnapshot: snapshot,
                    expectedRequestID: rawResult.requestID,
                    actualRequestID: wrongRequestID
                ),
                "The offline renderer returned cancellation for the wrong "
                    + "request."
            ),
            (
                .renderCancelledAfterSubmission(
                    sourceSnapshot: snapshot,
                    requestID: rawResult.requestID
                ),
                "Snapshot capture was cancelled after GPU submission "
                    + "completed."
            ),
            (
                .renderResultMismatch(
                    sourceSnapshot: snapshot,
                    renderResult: rawResult
                ),
                "The offline renderer returned an image that did not match "
                    + "the selected snapshot or output settings."
            ),
            (
                .cancelledAfterRender(
                    sourceSnapshot: snapshot,
                    renderResult: rawResult
                ),
                "Snapshot capture was cancelled before JPEG encoding began."
            ),
            (
                .jpegEncodingFailed(
                    sourceSnapshot: snapshot,
                    renderResult: rawResult,
                    failure: .couldNotCreateSRGBColorSpace
                ),
                "The system could not create the sRGB color space for JPEG "
                    + "export."
            ),
            (
                .jpegEncodingFailed(
                    sourceSnapshot: snapshot,
                    renderResult: rawResult,
                    failure: .couldNotCreateDataProvider
                ),
                "The rendered pixels could not be opened for JPEG export."
            ),
            (
                .jpegEncodingFailed(
                    sourceSnapshot: snapshot,
                    renderResult: rawResult,
                    failure: .couldNotCreateImage
                ),
                "The rendered pixel layout could not be converted into an "
                    + "image."
            ),
            (
                .jpegEncodingFailed(
                    sourceSnapshot: snapshot,
                    renderResult: rawResult,
                    failure: .couldNotCreateDestination
                ),
                "The system could not create an in-memory JPEG destination."
            ),
            (
                .jpegEncodingFailed(
                    sourceSnapshot: snapshot,
                    renderResult: rawResult,
                    failure: .destinationFinalizationFailed
                ),
                "The system could not finish encoding the JPEG."
            )
        ]

        for scenario in scenarios {
            let target = StubRealtimeSnapshotCaptureTarget(
                outcome: scenario.outcome
            )
            let model = SnapshotCaptureViewModel(
                captureTarget: target,
                renderSize: size
            )
            model.activatePresentation()

            await model.capture(outputMode: .surface)

            #expect(model.isFailurePresented)
            #expect(model.failureMessage == scenario.expectedMessage)
            #expect(model.failureAllowsExportRetry == false)
            #expect(model.isExporterPresented == false)
            #expect(model.exportDocument == nil)
            #expect(target.requests.count == 1)

            model.dismissFailure()
            #expect(model.isFailurePresented == false)
        }
    }

    @Test
    func jpegDocumentPublishesJPEGTypeAndExactFileWrapperBytes() throws {
        let size = try RenderPixelSize(width: 8, height: 6)
        let (_, artifact) = try Self.fixture(size: size, tick: 7)
        let document = JPEGArtifactDocument(artifact: artifact)

        #expect(JPEGArtifactDocument.readableContentTypes == [.jpeg])
        #expect(
            document.makeFileWrapper().regularFileContents
                == artifact.encodedData
        )
    }

    private nonisolated static func fixture(
        size: RenderPixelSize,
        tick: UInt64
    ) throws -> (
        snapshot: SimulationPresentationSnapshot,
        artifact: RenderedImageArtifact
    ) {
        let snapshot = SimulationPresentationSnapshot(
            cursor: SimulationCursor(
                sessionID: SimulationSessionID(),
                tick: SimulationTick(rawValue: tick)
            ),
            camera: Camera.lookingAt(.zero, from: SIMD3<Float>(0, 0, 8)),
            entityPresentations: []
        )
        let artifact = RenderedImageArtifact(
            format: .jpeg,
            encodedData: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            sourceRequestID: OffscreenRenderRequestID(),
            sourceCursor: snapshot.cursor,
            viewpoint: RenderViewpoint(
                id: RenderViewpointID(),
                revision: .zero,
                camera: snapshot.camera
            ),
            renderSettings: OffscreenRenderSettings(size: size),
            jpegSettings: JPEGEncodingSettings(quality: .maximum)
        )
        return (snapshot, artifact)
    }

    private nonisolated static func renderResult(
        artifact: RenderedImageArtifact,
        size: RenderPixelSize
    ) throws -> OffscreenRenderResult {
        OffscreenRenderResult(
            requestID: artifact.sourceRequestID,
            sourceCursor: artifact.sourceCursor,
            viewpoint: artifact.viewpoint,
            settings: artifact.renderSettings,
            image: try RenderedBGRA8SRGBImage(
                size: size,
                bytes: Data(repeating: 0xFF, count: size.pixelCount * 4)
            )
        )
    }
}

@MainActor
private final class StubRealtimeSnapshotCaptureTarget:
    PRealtimeSnapshotCaptureTarget {
    let outcome: RealtimeSnapshotCaptureOutcome
    private(set) var requests: [RealtimeSnapshotCaptureRequest] = []

    init(outcome: RealtimeSnapshotCaptureOutcome) {
        self.outcome = outcome
    }

    func capture(
        _ request: RealtimeSnapshotCaptureRequest
    ) async -> RealtimeSnapshotCaptureOutcome {
        requests.append(request)
        return outcome
    }
}

@MainActor
private final class SuspendedRealtimeSnapshotCaptureTarget:
    PRealtimeSnapshotCaptureTarget {
    private var continuation:
        CheckedContinuation<RealtimeSnapshotCaptureOutcome, Never>?
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var requests: [RealtimeSnapshotCaptureRequest] = []

    func capture(
        _ request: RealtimeSnapshotCaptureRequest
    ) async -> RealtimeSnapshotCaptureOutcome {
        requests.append(request)
        requestWaiters.forEach { $0.resume() }
        requestWaiters.removeAll()
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitForRequest() async {
        guard requests.isEmpty else {
            return
        }
        await withCheckedContinuation { continuation in
            requestWaiters.append(continuation)
        }
    }

    func complete(_ outcome: RealtimeSnapshotCaptureOutcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}

private struct SyntheticSaveError: LocalizedError {
    var errorDescription: String? {
        "Synthetic save failure."
    }
}
