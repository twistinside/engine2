import Foundation
import simd
import Testing
@testable import Engine2

struct RealtimeSnapshotCaptureConnectionTests {
    @Test @MainActor
    func selectsSnapshotAndViewpointTogetherBeforeRenderingSuspends() async throws {
        let initialSnapshot = Self.snapshot(tick: 3, cameraX: 0)
        let laterSnapshot = Self.snapshot(
            sessionID: initialSnapshot.cursor.sessionID,
            tick: 4,
            cameraX: 2
        )
        let selectedViewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: RenderViewpointRevision(rawValue: 7),
            camera: Camera.lookingAt(
                .zero,
                from: SIMD3<Float>(1, 0.5, 8)
            )
        )
        let laterViewpoint = RenderViewpoint(
            id: selectedViewpoint.id,
            revision: selectedViewpoint.revision.advanced(),
            camera: laterSnapshot.camera
        )
        let presentationSource = MutablePresentationSource(initialSnapshot)
        let viewpointSource = MutableViewpointSource(selectedViewpoint)
        let renderTarget = ControlledRenderTarget()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: presentationSource,
            viewpointSource: viewpointSource,
            renderTarget: renderTarget,
            encodeJPEG: Self.encodeJPEG
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderRequestID: OffscreenRenderRequestID(),
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 8, height: 6),
                outputMode: .viewSpaceNormals
            ),
            jpegSettings: JPEGEncodingSettings(quality: .maximum)
        )

        let capture = Task {
            await connection.capture(request)
        }
        let renderRequest = await renderTarget.waitForFirstRequest()

        // Mutate both live sources while GPU work is suspended. The request and
        // completed outcome must continue to carry the values selected together.
        presentationSource.snapshot = laterSnapshot
        viewpointSource.viewpoint = laterViewpoint

        let renderResult = try Self.renderResult(for: renderRequest)
        await renderTarget.complete(.completed(renderResult))
        let outcome = await capture.value
        let artifact = Self.artifact(
            for: renderResult,
            settings: request.jpegSettings
        )

        #expect(renderRequest.presentationSnapshot == initialSnapshot)
        #expect(renderRequest.viewpoint == selectedViewpoint)
        #expect(viewpointSource.resolvedDefaultCameras == [initialSnapshot.camera])
        #expect(
            outcome == .completed(
                sourceSnapshot: initialSnapshot,
                artifact: artifact
            )
        )
    }

    @Test @MainActor
    func overlappingCaptureReturnsBusyWithoutSamplingAgain() async throws {
        let snapshot = Self.snapshot(tick: 1, cameraX: 0)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: snapshot.camera
        )
        let presentationSource = MutablePresentationSource(snapshot)
        let viewpointSource = MutableViewpointSource(viewpoint)
        let renderTarget = ControlledRenderTarget()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: presentationSource,
            viewpointSource: viewpointSource,
            renderTarget: renderTarget,
            encodeJPEG: Self.encodeJPEG
        )
        let firstRequest = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            )
        )
        let secondRequest = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 6, height: 6)
            )
        )

        let firstCapture = Task {
            await connection.capture(firstRequest)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()

        let overlap = await connection.capture(secondRequest)

        #expect(overlap == .connectionBusy)
        #expect(viewpointSource.resolvedDefaultCameras.count == 1)
        #expect(await renderTarget.requestCount() == 1)

        let result = try Self.renderResult(for: admittedRequest)
        await renderTarget.complete(.completed(result))
        _ = await firstCapture.value
    }

    @Test @MainActor
    func overlapDuringJPEGEncodingReturnsBusyWithoutResampling() async throws {
        let snapshot = Self.snapshot(tick: 11, cameraX: 0)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: snapshot.camera
        )
        let presentationSource = MutablePresentationSource(snapshot)
        let viewpointSource = MutableViewpointSource(viewpoint)
        let renderTarget = ControlledRenderTarget()
        let encoder = SuspendedJPEGEncoder()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: presentationSource,
            viewpointSource: viewpointSource,
            renderTarget: renderTarget,
            encodeJPEG: { result, settings in
                await encoder.encode(result, settings: settings)
            }
        )
        let firstRequest = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            )
        )
        let secondRequest = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 6, height: 6)
            )
        )

        let firstCapture = Task {
            await connection.capture(firstRequest)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()
        let renderResult = try Self.renderResult(for: admittedRequest)
        await renderTarget.complete(.completed(renderResult))
        await encoder.waitForRequest()

        let overlap = await connection.capture(secondRequest)

        #expect(overlap == .connectionBusy)
        #expect(presentationSource.sampleCount == 1)
        #expect(viewpointSource.resolvedDefaultCameras.count == 1)
        #expect(await renderTarget.requestCount() == 1)

        let artifact = Self.artifact(
            for: renderResult,
            settings: firstRequest.jpegSettings
        )
        await encoder.complete(.success(artifact))
        #expect(
            await firstCapture.value
                == .completed(
                    sourceSnapshot: snapshot,
                    artifact: artifact
                )
        )
    }

    @Test @MainActor
    func preCancelledCaptureDoesNotSampleSourcesOrRender() async throws {
        let snapshot = Self.snapshot(tick: 17, cameraX: 0)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: snapshot.camera
        )
        let presentationSource = MutablePresentationSource(snapshot)
        let viewpointSource = MutableViewpointSource(viewpoint)
        let renderTarget = ControlledRenderTarget()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: presentationSource,
            viewpointSource: viewpointSource,
            renderTarget: renderTarget,
            encodeJPEG: Self.encodeJPEG
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            )
        )

        let capture = Task {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            return await connection.capture(request)
        }
        let outcome = await capture.value

        #expect(outcome == .cancelledBeforeRender)
        #expect(presentationSource.sampleCount == 0)
        #expect(viewpointSource.resolvedDefaultCameras.isEmpty)
        #expect(await renderTarget.requestCount() == 0)
    }

    @Test @MainActor
    func cancellationAfterRawRenderRetainsExactSnapshotAndResult() async throws {
        let snapshot = Self.snapshot(tick: 23, cameraX: 0)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: snapshot.camera
        )
        let renderTarget = ControlledRenderTarget()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: MutablePresentationSource(snapshot),
            viewpointSource: MutableViewpointSource(viewpoint),
            renderTarget: renderTarget,
            encodeJPEG: Self.encodeJPEG
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            )
        )

        let capture = Task {
            await connection.capture(request)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()
        let renderResult = try Self.renderResult(for: admittedRequest)
        capture.cancel()
        await renderTarget.complete(.completed(renderResult))

        #expect(
            await capture.value
                == .cancelledAfterRender(
                    sourceSnapshot: snapshot,
                    renderResult: renderResult
                )
        )
    }

    @Test @MainActor
    func mismatchedRenderProvenancePreventsJPEGEncoding() async throws {
        let snapshot = Self.snapshot(tick: 31, cameraX: 0)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: snapshot.camera
        )
        let renderTarget = ControlledRenderTarget()
        let encodingCalls = EncodingCallCounter()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: MutablePresentationSource(snapshot),
            viewpointSource: MutableViewpointSource(viewpoint),
            renderTarget: renderTarget,
            encodeJPEG: { result, settings in
                await encodingCalls.record()
                return .success(
                    Self.artifact(for: result, settings: settings)
                )
            }
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            )
        )

        let capture = Task {
            await connection.capture(request)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()
        let validResult = try Self.renderResult(for: admittedRequest)
        let mismatchedCursor = SimulationCursor(
            sessionID: validResult.sourceCursor.sessionID,
            tick: validResult.sourceCursor.tick.advanced()
        )
        let mismatchedResult = OffscreenRenderResult(
            requestID: validResult.requestID,
            sourceCursor: mismatchedCursor,
            viewpoint: validResult.viewpoint,
            settings: validResult.settings,
            image: validResult.image
        )
        await renderTarget.complete(.completed(mismatchedResult))

        #expect(
            await capture.value
                == .renderResultMismatch(
                    sourceSnapshot: snapshot,
                    renderResult: mismatchedResult
                )
        )
        #expect(await encodingCalls.count() == 0)
    }

    @Test @MainActor
    func everyPreEncodingRenderTerminalPreservesTheSelectedSnapshot() async throws {
        let snapshot = Self.snapshot(tick: 37, cameraX: 1)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: RenderViewpointRevision(rawValue: 9),
            camera: snapshot.camera
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderRequestID: OffscreenRenderRequestID(),
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            )
        )
        let rejection = OffscreenRenderRejection.runtimeBusy
        let failure = OffscreenRenderFailure(
            stage: .gpuExecution,
            backendDescription: "scripted GPU failure"
        )
        let wrongRequestID = OffscreenRenderRequestID()
        let terminals: [
            (
                render: OffscreenRenderOutcome,
                expected: RealtimeSnapshotCaptureOutcome
            )
        ] = [
            (
                .rejected(rejection),
                .renderRejected(
                    sourceSnapshot: snapshot,
                    rejection: rejection
                )
            ),
            (
                .failed(failure),
                .renderFailed(
                    sourceSnapshot: snapshot,
                    failure: failure
                )
            ),
            (
                .cancelledAfterSubmission(
                    requestID: request.renderRequestID
                ),
                .renderCancelledAfterSubmission(
                    sourceSnapshot: snapshot,
                    requestID: request.renderRequestID
                )
            ),
            (
                .cancelledAfterSubmission(requestID: wrongRequestID),
                .renderCancellationRequestIDMismatch(
                    sourceSnapshot: snapshot,
                    expectedRequestID: request.renderRequestID,
                    actualRequestID: wrongRequestID
                )
            )
        ]

        for terminal in terminals {
            let renderTarget = ControlledRenderTarget()
            let encodingCalls = EncodingCallCounter()
            let connection = RealtimeSnapshotCaptureConnection(
                presentationSource: MutablePresentationSource(snapshot),
                viewpointSource: MutableViewpointSource(viewpoint),
                renderTarget: renderTarget,
                encodeJPEG: { result, settings in
                    await encodingCalls.record()
                    return .success(
                        Self.artifact(for: result, settings: settings)
                    )
                }
            )
            let capture = Task {
                await connection.capture(request)
            }

            let admittedRequest = await renderTarget.waitForFirstRequest()
            #expect(admittedRequest.id == request.renderRequestID)
            await renderTarget.complete(terminal.render)

            #expect(await capture.value == terminal.expected)
            #expect(await encodingCalls.count() == 0)
        }
    }

    @Test @MainActor
    func jpegFailurePreservesSelectedSnapshotAndRawResult() async throws {
        let snapshot = Self.snapshot(tick: 41, cameraX: -1)
        let viewpoint = RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: snapshot.camera
        )
        let renderTarget = ControlledRenderTarget()
        let encodingCalls = EncodingCallCounter()
        let encodingFailure =
            JPEGArtifactEncoderError.destinationFinalizationFailed
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: MutablePresentationSource(snapshot),
            viewpointSource: MutableViewpointSource(viewpoint),
            renderTarget: renderTarget,
            encodeJPEG: { _, _ in
                await encodingCalls.record()
                return .failure(encodingFailure)
            }
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            )
        )
        let capture = Task {
            await connection.capture(request)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()
        let renderResult = try Self.renderResult(for: admittedRequest)
        await renderTarget.complete(.completed(renderResult))

        #expect(
            await capture.value == .jpegEncodingFailed(
                sourceSnapshot: snapshot,
                renderResult: renderResult,
                failure: encodingFailure
            )
        )
        #expect(await encodingCalls.count() == 1)
    }

    private nonisolated static func encodeJPEG(
        _ result: OffscreenRenderResult,
        settings: JPEGEncodingSettings
    ) async -> Result<RenderedImageArtifact, JPEGArtifactEncoderError> {
        .success(Self.artifact(for: result, settings: settings))
    }

    private static func snapshot(
        sessionID: SimulationSessionID = SimulationSessionID(),
        tick: UInt64,
        cameraX: Float
    ) -> SimulationPresentationSnapshot {
        SimulationPresentationSnapshot(
            cursor: SimulationCursor(
                sessionID: sessionID,
                tick: SimulationTick(rawValue: tick)
            ),
            camera: Camera.lookingAt(
                .zero,
                from: SIMD3<Float>(cameraX, 0, 8)
            ),
            entityPresentations: []
        )
    }

    private static func renderResult(
        for request: OffscreenRenderRequest
    ) throws -> OffscreenRenderResult {
        OffscreenRenderResult(
            requestID: request.id,
            sourceCursor: request.presentationSnapshot.cursor,
            viewpoint: request.viewpoint,
            settings: request.settings,
            image: try RenderedBGRA8SRGBImage(
                size: request.settings.size,
                bytes: Data(
                    repeating: 255,
                    count: request.settings.size.pixelCount * 4
                )
            )
        )
    }

    private nonisolated static func artifact(
        for result: OffscreenRenderResult,
        settings: JPEGEncodingSettings
    ) -> RenderedImageArtifact {
        RenderedImageArtifact(
            format: .jpeg,
            encodedData: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            sourceRequestID: result.requestID,
            sourceCursor: result.sourceCursor,
            viewpoint: result.viewpoint,
            renderSettings: result.settings,
            jpegSettings: settings
        )
    }
}

@MainActor
private final class MutablePresentationSource: PSimulationPresentationSource {
    var snapshot: SimulationPresentationSnapshot
    private(set) var sampleCount = 0

    var latestPresentationSnapshot: SimulationPresentationSnapshot {
        sampleCount += 1
        return snapshot
    }

    init(_ snapshot: SimulationPresentationSnapshot) {
        self.snapshot = snapshot
    }
}

@MainActor
private final class MutableViewpointSource: PRenderViewpointSource {
    var viewpoint: RenderViewpoint
    private(set) var resolvedDefaultCameras: [Camera] = []

    init(_ viewpoint: RenderViewpoint) {
        self.viewpoint = viewpoint
    }

    func resolveViewpoint(defaultCamera: Camera) -> RenderViewpoint {
        resolvedDefaultCameras.append(defaultCamera)
        return viewpoint
    }
}

private actor ControlledRenderTarget: POffscreenRenderTarget {
    private var requests: [OffscreenRenderRequest] = []
    private var continuation: CheckedContinuation<OffscreenRenderOutcome, Never>?
    private var firstRequestWaiters: [
        CheckedContinuation<OffscreenRenderRequest, Never>
    ] = []

    func render(
        _ request: OffscreenRenderRequest
    ) async -> OffscreenRenderOutcome {
        requests.append(request)
        firstRequestWaiters.forEach { $0.resume(returning: request) }
        firstRequestWaiters.removeAll()
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitForFirstRequest() async -> OffscreenRenderRequest {
        if let request = requests.first {
            return request
        }
        return await withCheckedContinuation { continuation in
            firstRequestWaiters.append(continuation)
        }
    }

    func requestCount() -> Int {
        requests.count
    }

    func complete(_ outcome: OffscreenRenderOutcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}

private actor SuspendedJPEGEncoder {
    private var continuation: CheckedContinuation<
        Result<RenderedImageArtifact, JPEGArtifactEncoderError>,
        Never
    >?
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []
    private var didReceiveRequest = false

    func encode(
        _ result: OffscreenRenderResult,
        settings: JPEGEncodingSettings
    ) async -> Result<RenderedImageArtifact, JPEGArtifactEncoderError> {
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

    func complete(
        _ result: Result<
            RenderedImageArtifact,
            JPEGArtifactEncoderError
        >
    ) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

private actor EncodingCallCounter {
    private var callCount = 0

    func record() {
        callCount += 1
    }

    func count() -> Int {
        callCount
    }
}
