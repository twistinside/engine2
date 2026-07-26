import Foundation
import simd
import Testing
@testable import Engine2

struct RealtimeSnapshotCaptureConnectionTests {
    @Test
    func locksSelectedSnapshotCameraBeforeRenderingSuspends() async throws {
        let initialSnapshot = snapshot(tick: 3, cameraX: 0)
        let laterSnapshot = snapshot(
            sessionID: initialSnapshot.cursor.sessionID,
            tick: 4,
            cameraX: 2
        )
        let viewpointID = RenderViewpointID()
        let presentationSource = MutablePresentationSource(initialSnapshot)
        let renderTarget = ControlledRenderTarget()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: presentationSource,
            renderTarget: renderTarget,
            viewpointID: viewpointID,
            artifactEncoder: CorrelatedArtifactEncoder()
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderRequestID: OffscreenRenderRequestID(),
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 8, height: 6),
                outputMode: .viewSpaceNormals
            ),
            encoding: .jpeg(quality: .maximum)
        )

        let capture = Task {
            await connection.capture(request)
        }
        let renderRequest = await renderTarget.waitForFirstRequest()

        // Mutate the live source while GPU work is suspended. The request and
        // completed outcome must continue to carry the selected value.
        presentationSource.snapshot = laterSnapshot

        let renderResult = try renderResult(for: renderRequest)
        await renderTarget.complete(.completed(renderResult))
        let outcome = await capture.value
        let artifact = Self.artifact(
            for: renderResult,
            encoding: request.encoding
        )

        #expect(renderRequest.presentationSnapshot == initialSnapshot)
        #expect(
            renderRequest.viewpoint == RenderViewpoint(
                id: viewpointID,
                revision: .zero,
                camera: initialSnapshot.camera
            )
        )
        #expect(
            outcome == .completed(
                sourceSnapshot: initialSnapshot,
                artifact: artifact
            )
        )
    }

    @Test
    func sequentialCapturesKeepOneIdentityAndFollowSimulationPublications() async throws {
        let firstSnapshot = snapshot(tick: 43, cameraX: -2)
        let secondSnapshot = snapshot(
            sessionID: firstSnapshot.cursor.sessionID,
            tick: 44,
            cameraX: 3
        )
        let viewpointID = RenderViewpointID()
        let presentationSource = MutablePresentationSource(firstSnapshot)
        let renderTarget = ControlledRenderTarget()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: presentationSource,
            renderTarget: renderTarget,
            viewpointID: viewpointID,
            artifactEncoder: CorrelatedArtifactEncoder()
        )
        let firstRequest = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            ),
            encoding: .jpeg(quality: .observation)
        )
        let secondRequest = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 8, height: 6)
            ),
            encoding: .png
        )

        let firstCapture = Task {
            await connection.capture(firstRequest)
        }
        let firstRenderRequest = await renderTarget.waitForRequest(at: 0)
        let firstRenderResult = try renderResult(for: firstRenderRequest)
        await renderTarget.complete(.completed(firstRenderResult))
        guard case let .completed(firstSelectedSnapshot, firstArtifact) =
            await firstCapture.value
        else {
            Issue.record("Expected first capture to complete")
            return
        }

        presentationSource.snapshot = secondSnapshot

        let secondCapture = Task {
            await connection.capture(secondRequest)
        }
        let secondRenderRequest = await renderTarget.waitForRequest(at: 1)
        let secondRenderResult = try renderResult(for: secondRenderRequest)
        await renderTarget.complete(.completed(secondRenderResult))
        guard case let .completed(secondSelectedSnapshot, secondArtifact) =
            await secondCapture.value
        else {
            Issue.record("Expected second capture to complete")
            return
        }

        #expect(firstSelectedSnapshot == firstSnapshot)
        #expect(secondSelectedSnapshot == secondSnapshot)
        #expect(firstRenderRequest.presentationSnapshot == firstSnapshot)
        #expect(secondRenderRequest.presentationSnapshot == secondSnapshot)
        #expect(
            firstArtifact.viewpoint == RenderViewpoint(
                id: viewpointID,
                revision: .zero,
                camera: firstSnapshot.camera
            )
        )
        #expect(
            secondArtifact.viewpoint == RenderViewpoint(
                id: viewpointID,
                revision: .zero,
                camera: secondSnapshot.camera
            )
        )
        #expect(firstArtifact.sourceCursor == firstSnapshot.cursor)
        #expect(secondArtifact.sourceCursor == secondSnapshot.cursor)
        #expect(firstArtifact.encoding == firstRequest.encoding)
        #expect(secondArtifact.encoding == secondRequest.encoding)
        #expect(presentationSource.sampleCount == 2)
    }

    @Test
    func overlappingCaptureReturnsBusyWithoutSamplingAgain() async throws {
        let snapshot = snapshot(tick: 1, cameraX: 0)
        let presentationSource = MutablePresentationSource(snapshot)
        let renderTarget = ControlledRenderTarget()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: presentationSource,
            renderTarget: renderTarget,
            artifactEncoder: CorrelatedArtifactEncoder()
        )
        let firstRequest = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            ),
            encoding: .jpeg(quality: .observation)
        )
        let secondRequest = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 6, height: 6)
            ),
            encoding: .jpeg(quality: .observation)
        )

        let firstCapture = Task {
            await connection.capture(firstRequest)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()

        let overlap = await connection.capture(secondRequest)

        #expect(overlap == .connectionBusy)
        #expect(presentationSource.sampleCount == 1)
        #expect(await renderTarget.requestCount() == 1)

        let result = try renderResult(for: admittedRequest)
        await renderTarget.complete(.completed(result))
        _ = await firstCapture.value
    }

    @Test
    func overlapDuringArtifactEncodingReturnsBusyWithoutResampling() async throws {
        let snapshot = snapshot(tick: 11, cameraX: 0)
        let presentationSource = MutablePresentationSource(snapshot)
        let renderTarget = ControlledRenderTarget()
        let encoder = SuspendedArtifactEncoder()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: presentationSource,
            renderTarget: renderTarget,
            artifactEncoder: encoder
        )
        let firstRequest = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            ),
            encoding: .jpeg(quality: .observation)
        )
        let secondRequest = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 6, height: 6)
            ),
            encoding: .jpeg(quality: .observation)
        )

        let firstCapture = Task {
            await connection.capture(firstRequest)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()
        let renderResult = try renderResult(for: admittedRequest)
        await renderTarget.complete(.completed(renderResult))
        await encoder.waitForRequest()

        let overlap = await connection.capture(secondRequest)

        #expect(overlap == .connectionBusy)
        #expect(presentationSource.sampleCount == 1)
        #expect(await renderTarget.requestCount() == 1)

        let artifact = Self.artifact(
            for: renderResult,
            encoding: firstRequest.encoding
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

    @Test
    func preCancelledCaptureDoesNotSampleSourcesOrRender() async throws {
        let snapshot = snapshot(tick: 17, cameraX: 0)
        let presentationSource = MutablePresentationSource(snapshot)
        let renderTarget = ControlledRenderTarget()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: presentationSource,
            renderTarget: renderTarget,
            artifactEncoder: CorrelatedArtifactEncoder()
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            ),
            encoding: .jpeg(quality: .observation)
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
        #expect(await renderTarget.requestCount() == 0)
    }

    @Test
    func cancellationAfterRawRenderRetainsExactSnapshotAndResult() async throws {
        let snapshot = snapshot(tick: 23, cameraX: 0)
        let renderTarget = ControlledRenderTarget()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: MutablePresentationSource(snapshot),
            renderTarget: renderTarget,
            artifactEncoder: CorrelatedArtifactEncoder()
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            ),
            encoding: .jpeg(quality: .observation)
        )

        let capture = Task {
            await connection.capture(request)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()
        let renderResult = try renderResult(for: admittedRequest)
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

    @Test
    func mismatchedRenderProvenancePreventsArtifactEncoding() async throws {
        let snapshot = snapshot(tick: 31, cameraX: 0)
        let renderTarget = ControlledRenderTarget()
        let encoder = CountingArtifactEncoder()
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: MutablePresentationSource(snapshot),
            renderTarget: renderTarget,
            artifactEncoder: encoder
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            ),
            encoding: .jpeg(quality: .observation)
        )

        let capture = Task {
            await connection.capture(request)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()
        let validResult = try renderResult(for: admittedRequest)
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
        #expect(await encoder.count() == 0)
    }

    @Test
    func everyPreEncodingRenderTerminalPreservesTheSelectedSnapshot() async throws {
        let snapshot = snapshot(tick: 37, cameraX: 1)
        let request = RealtimeSnapshotCaptureRequest(
            renderRequestID: OffscreenRenderRequestID(),
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            ),
            encoding: .jpeg(quality: .observation)
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
            let encoder = CountingArtifactEncoder()
            let connection = RealtimeSnapshotCaptureConnection(
                presentationSource: MutablePresentationSource(snapshot),
                renderTarget: renderTarget,
                artifactEncoder: encoder
            )
            let capture = Task {
                await connection.capture(request)
            }

            let admittedRequest = await renderTarget.waitForFirstRequest()
            #expect(admittedRequest.id == request.renderRequestID)
            await renderTarget.complete(terminal.render)

            #expect(await capture.value == terminal.expected)
            #expect(await encoder.count() == 0)
        }
    }

    @Test
    func artifactFailurePreservesSelectedSnapshotAndRawResult() async throws {
        let snapshot = snapshot(tick: 41, cameraX: -1)
        let renderTarget = ControlledRenderTarget()
        let encodingFailure =
            ImageArtifactEncoderError.destinationFinalizationFailed
        let encoder = CountingArtifactEncoder(failure: encodingFailure)
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: MutablePresentationSource(snapshot),
            renderTarget: renderTarget,
            artifactEncoder: encoder
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            ),
            encoding: .jpeg(quality: .observation)
        )
        let capture = Task {
            await connection.capture(request)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()
        let renderResult = try renderResult(for: admittedRequest)
        await renderTarget.complete(.completed(renderResult))

        #expect(
            await capture.value == .artifactEncodingFailed(
                sourceSnapshot: snapshot,
                renderResult: renderResult,
                failure: encodingFailure
            )
        )
        #expect(await encoder.count() == 1)
    }

    @Test
    func mismatchedArtifactProvenanceRetainsRawAndEncodedValues() async throws {
        let snapshot = snapshot(tick: 47, cameraX: 1)
        let renderTarget = ControlledRenderTarget()
        let encoder = CountingArtifactEncoder(mismatchesEncoding: true)
        let connection = RealtimeSnapshotCaptureConnection(
            presentationSource: MutablePresentationSource(snapshot),
            renderTarget: renderTarget,
            artifactEncoder: encoder
        )
        let request = RealtimeSnapshotCaptureRequest(
            renderSettings: OffscreenRenderSettings(
                size: try RenderPixelSize(width: 4, height: 4)
            ),
            encoding: .png
        )

        let capture = Task {
            await connection.capture(request)
        }
        let admittedRequest = await renderTarget.waitForFirstRequest()
        let renderResult = try renderResult(for: admittedRequest)
        await renderTarget.complete(.completed(renderResult))
        let mismatchedArtifact = Self.artifact(
            for: renderResult,
            encoding: .jpeg(quality: .observation)
        )

        #expect(
            await capture.value == .artifactResultMismatch(
                sourceSnapshot: snapshot,
                renderResult: renderResult,
                artifact: mismatchedArtifact
            )
        )
        #expect(await encoder.count() == 1)
    }

    private func snapshot(
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

    private func renderResult(for request: OffscreenRenderRequest) throws -> OffscreenRenderResult {
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

    fileprivate nonisolated static func artifact(
        for result: OffscreenRenderResult,
        encoding: ImageArtifactEncoding
    ) -> RenderedImageArtifact {
        let encodedData = switch encoding {
        case .jpeg:
            Data([0xFF, 0xD8, 0xFF, 0xD9])
        case .png:
            Data([0x89, 0x50, 0x4E, 0x47])
        }
        return RenderedImageArtifact(
            encoding: encoding,
            encodedData: encodedData,
            sourceRequestID: result.requestID,
            sourceCursor: result.sourceCursor,
            viewpoint: result.viewpoint,
            renderSettings: result.settings
        )
    }
}

private extension RealtimeSnapshotCaptureConnectionTests {
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

    private actor ControlledRenderTarget: POffscreenRenderTarget {
        private var requests: [OffscreenRenderRequest] = []
        private var continuation: CheckedContinuation<OffscreenRenderOutcome, Never>?
        private var requestWaiters: [
            Int: [CheckedContinuation<OffscreenRenderRequest, Never>]
        ] = [:]

        func render(_ request: OffscreenRenderRequest) async -> OffscreenRenderOutcome {
            let requestIndex = requests.count
            requests.append(request)
            requestWaiters.removeValue(forKey: requestIndex)?.forEach {
                $0.resume(returning: request)
            }
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }

        func waitForFirstRequest() async -> OffscreenRenderRequest {
            await waitForRequest(at: 0)
        }

        func waitForRequest(at index: Int) async -> OffscreenRenderRequest {
            precondition(index >= 0)
            if requests.indices.contains(index) {
                return requests[index]
            }
            return await withCheckedContinuation { continuation in
                requestWaiters[index, default: []].append(continuation)
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

    private struct CorrelatedArtifactEncoder: PImageArtifactEncoder {
        func encode(
            _ result: OffscreenRenderResult,
            as encoding: ImageArtifactEncoding
        ) async throws(ImageArtifactEncoderError) -> RenderedImageArtifact {
            RealtimeSnapshotCaptureConnectionTests.artifact(
                for: result,
                encoding: encoding
            )
        }
    }

    private actor SuspendedArtifactEncoder: PImageArtifactEncoder {
        private var continuation: CheckedContinuation<
            Result<RenderedImageArtifact, ImageArtifactEncoderError>,
            Never
        >?
        private var requestWaiters: [CheckedContinuation<Void, Never>] = []
        private var didReceiveRequest = false

        func encode(
            _ result: OffscreenRenderResult,
            as encoding: ImageArtifactEncoding
        ) async throws(ImageArtifactEncoderError) -> RenderedImageArtifact {
            didReceiveRequest = true
            requestWaiters.forEach { $0.resume() }
            requestWaiters.removeAll()
            let result = await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
            switch result {
            case let .success(artifact):
                return artifact
            case let .failure(failure):
                throw failure
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
                ImageArtifactEncoderError
            >
        ) {
            continuation?.resume(returning: result)
            continuation = nil
        }
    }

    private actor CountingArtifactEncoder: PImageArtifactEncoder {
        private let failure: ImageArtifactEncoderError?
        private let mismatchesEncoding: Bool
        private var callCount = 0

        init(
            failure: ImageArtifactEncoderError? = nil,
            mismatchesEncoding: Bool = false
        ) {
            self.failure = failure
            self.mismatchesEncoding = mismatchesEncoding
        }

        func encode(
            _ result: OffscreenRenderResult,
            as encoding: ImageArtifactEncoding
        ) async throws(ImageArtifactEncoderError) -> RenderedImageArtifact {
            callCount += 1
            if let failure {
                throw failure
            }
            let resultEncoding: ImageArtifactEncoding
            if mismatchesEncoding {
                resultEncoding = switch encoding {
                case .jpeg:
                    .png
                case .png:
                    .jpeg(quality: .observation)
                }
            } else {
                resultEncoding = encoding
            }
            return RealtimeSnapshotCaptureConnectionTests.artifact(
                for: result,
                encoding: resultEncoding
            )
        }

        func count() -> Int {
            callCount
        }
    }
}
