import Foundation
import simd
import Testing
import UniformTypeIdentifiers
@testable import Engine2

struct SnapshotCaptureViewModelTests {
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
    private var didReceiveRequest = false

    func capture(
        _ request: RealtimeSnapshotCaptureRequest
    ) async -> RealtimeSnapshotCaptureOutcome {
        didReceiveRequest = true
        requestWaiters.forEach { $0.resume() }
        requestWaiters.removeAll()
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitForRequest() async {
        guard !didReceiveRequest else {
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
