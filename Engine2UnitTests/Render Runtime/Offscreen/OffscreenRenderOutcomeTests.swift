import Foundation
import simd
import Testing
@testable import Engine2

struct OffscreenRenderOutcomeTests {
    @Test func completedRejectedAndFailedOutcomesRetainValueEquality() throws {
        let completedResult = try result()
        let limits = OffscreenRenderLimits(
            maxDimension: 2_048,
            maxPixelCount: 4_194_304
        )
        let requestedSize = try RenderPixelSize(width: 4_096, height: 4_096)
        let failure = OffscreenRenderFailure(
            stage: .gpuExecution,
            backendDescription: "device removed"
        )

        let completed = OffscreenRenderOutcome.completed(completedResult)
        let busy = OffscreenRenderOutcome.rejected(.runtimeBusy)
        let cancelledBefore = OffscreenRenderOutcome.rejected(
            .cancelledBeforeSubmission
        )
        let cancelledAfter = OffscreenRenderOutcome.cancelledAfterSubmission(
            requestID: completedResult.requestID
        )
        let invalidViewpoint = OffscreenRenderOutcome.rejected(.invalidViewpoint)
        let missingEntityID = EntityID(index: 19, generation: 2)
        let invalidPresentation = OffscreenRenderOutcome.rejected(
            .invalidPresentation(
                .missingPosition(
                    entityID: missingEntityID
                )
            )
        )
        let excessiveSize = OffscreenRenderOutcome.rejected(
            .exceedsLimits(requested: requestedSize, limits: limits)
        )
        let excessiveInstances = OffscreenRenderOutcome.rejected(
            .instanceLimitExceeded(requested: 1_001, maximum: 1_000)
        )
        let failed = OffscreenRenderOutcome.failed(failure)

        #expect(completed == .completed(completedResult))
        #expect(busy == .rejected(.runtimeBusy))
        #expect(cancelledBefore == .rejected(.cancelledBeforeSubmission))
        #expect(
            cancelledAfter == .cancelledAfterSubmission(
                requestID: completedResult.requestID
            )
        )
        #expect(invalidViewpoint == .rejected(.invalidViewpoint))
        #expect(
            invalidPresentation == .rejected(
                .invalidPresentation(
                    .missingPosition(
                        entityID: missingEntityID
                    )
                )
            )
        )
        #expect(
            excessiveSize == .rejected(
                .exceedsLimits(requested: requestedSize, limits: limits)
            )
        )
        #expect(
            excessiveInstances == .rejected(
                .instanceLimitExceeded(requested: 1_001, maximum: 1_000)
            )
        )
        #expect(failed == .failed(failure))
        #expect(completed != busy)
        #expect(cancelledBefore != cancelledAfter)
        #expect(failed != excessiveInstances)
        #expect(invalidPresentation != invalidViewpoint)

        requireSendable(completed)
        requireSendable(cancelledAfter)
        requireSendable(failed)
        requireError(failure)
    }

    private func result() throws -> OffscreenRenderResult {
        let size = try RenderPixelSize(width: 1, height: 1)
        let requestUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000121"
        )!
        let requestID = OffscreenRenderRequestID(rawValue: requestUUID)
        let sessionUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000122"
        )!
        let sessionID = SimulationSessionID(rawValue: sessionUUID)
        let tick = SimulationTick(rawValue: 3)
        let sourceCursor = SimulationCursor(
            sessionID: sessionID,
            tick: tick
        )
        let viewpointUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000123"
        )!
        let viewpointID = RenderViewpointID(rawValue: viewpointUUID)
        let viewpointRevision = RenderViewpointRevision(rawValue: 4)
        let camera = Camera(
            position: SIMD3<Float>(0, 0, 5),
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let viewpoint = RenderViewpoint(
            id: viewpointID,
            revision: viewpointRevision,
            camera: camera
        )
        let settings = OffscreenRenderSettings(
            size: size,
            outputMode: .surface,
            exposure: .validation
        )
        let bytes = Data([0, 0, 0, 255])
        let image = try RenderedBGRA8SRGBImage(size: size, bytes: bytes)
        return OffscreenRenderResult(
            requestID: requestID,
            sourceCursor: sourceCursor,
            viewpoint: viewpoint,
            settings: settings,
            image: image
        )
    }

    private func requireSendable(_ value: some Sendable) {}

    private func requireError(_ value: some Error) {}
}
