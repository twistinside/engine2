import CoreGraphics
import Foundation
import ImageIO
import simd
import Testing
import UniformTypeIdentifiers
@testable import Engine2

struct AgentSessionConfigurationTests {
    @MainActor
    @Test
    func executesReplaysAndContinuesThroughTheClosedAssemblyBoundary() async throws {
        let agentSessionID = AgentSessionID(
            rawValue: UUID(
                uuidString: "50000000-0000-0000-0000-000000000001"
            )!
        )
        let simulationSessionID = SimulationSessionID(
            rawValue: UUID(
                uuidString: "50000000-0000-0000-0000-000000000002"
            )!
        )
        let assembly = try AgentSessionConfiguration().makeAssembly(
            gameContent: BasicGameContent(),
            agentSessionID: agentSessionID,
            simulationSessionID: simulationSessionID
        )

        // Retain only the values deliberately exposed by the closed assembly.
        // No Simulation, Render, offline coordinator, or latest-value source is
        // available to this integration client.
        let sessionID = assembly.sessionID
        let initialCursor = assembly.initialCursor
        let firstRequestID = assembly.firstRequestID
        let target = assembly.target

        #expect(sessionID == agentSessionID)
        #expect(firstRequestID.sessionID == sessionID)
        #expect(firstRequestID.sequence == .first)
        #expect(initialCursor.sessionID == simulationSessionID)
        #expect(initialCursor.tick == .zero)

        let viewpointID = RenderViewpointID(
            rawValue: UUID(
                uuidString: "50000000-0000-0000-0000-000000000003"
            )!
        )
        let firstViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: RenderViewpointRevision(rawValue: 11),
            camera: Camera.lookingAt(
                .zero,
                from: SIMD3<Float>(0, 0, 8)
            )
        )
        let firstRenderSettings = OffscreenRenderSettings(
            size: try RenderPixelSize(width: 64, height: 48),
            outputMode: .surface,
            exposure: .validation
        )
        let firstJPEGSettings = JPEGEncodingSettings(
            quality: try JPEGQuality(0.72)
        )
        let firstRequest = AgentCaptureRequest(
            id: firstRequestID,
            expectedCursor: initialCursor,
            stepCount: .one,
            renderRequestID: OffscreenRenderRequestID(
                rawValue: UUID(
                    uuidString: "50000000-0000-0000-0000-000000000004"
                )!
            ),
            viewpoint: firstViewpoint,
            renderSettings: firstRenderSettings,
            jpegSettings: firstJPEGSettings
        )

        let firstResponse = try Self.executedResponse(
            from: await target.capture(firstRequest)
        )
        let firstResult = try Self.completedCapture(from: firstResponse)

        #expect(firstResponse.requestID == firstRequestID)
        #expect(firstResponse.knownCursor == initialCursor.advanced())
        #expect(firstResult.advanceResult.initialCursor == initialCursor)
        #expect(
            firstResult.advanceResult.finalCursor ==
            firstResponse.knownCursor
        )
        #expect(firstResult.advanceResult.completedStepCount.rawValue == 1)
        #expect(
            firstResult.advanceResult.finalPresentationSnapshot.cursor ==
            firstResponse.knownCursor
        )
        try Self.assertArtifact(
            firstResult.artifact,
            requestID: firstRequest.renderRequestID,
            cursor: firstResponse.knownCursor,
            viewpoint: firstViewpoint,
            renderSettings: firstRenderSettings,
            jpegSettings: firstJPEGSettings
        )

        let secondSequence = try #require(firstRequestID.sequence.successor())
        let secondRequestID = AgentSessionRequestID(
            sessionID: sessionID,
            sequence: secondSequence
        )
        let secondViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: firstViewpoint.revision.advanced(),
            camera: Camera.lookingAt(
                .zero,
                from: SIMD3<Float>(0.75, 0.25, 8)
            )
        )
        let secondRenderSettings = OffscreenRenderSettings(
            size: try RenderPixelSize(width: 48, height: 36),
            outputMode: .viewSpaceNormals,
            exposure: ManualExposure(multiplier: 1.1)
        )
        let secondJPEGSettings = JPEGEncodingSettings(quality: .maximum)
        let secondRequest = AgentCaptureRequest.current(
            id: secondRequestID,
            expectedCursor: firstResponse.knownCursor,
            renderRequestID: OffscreenRenderRequestID(
                rawValue: UUID(
                    uuidString: "50000000-0000-0000-0000-000000000005"
                )!
            ),
            viewpoint: secondViewpoint,
            renderSettings: secondRenderSettings,
            jpegSettings: secondJPEGSettings
        )

        let secondResponse = try Self.executedResponse(
            from: await target.capture(secondRequest)
        )
        let secondResult = try Self.completedCurrentCapture(
            from: secondResponse
        )

        // Sequence one renders the retained completed value from another
        // viewpoint without changing the authoritative cursor.
        #expect(secondResponse.requestID == secondRequestID)
        #expect(
            secondResult.sourceSnapshot.cursor ==
            firstResponse.knownCursor
        )
        #expect(secondResponse.knownCursor == firstResponse.knownCursor)
        #expect(secondResponse.knownCursor.tick == SimulationTick(rawValue: 1))
        #expect(secondResponse.knownCursor.sessionID == simulationSessionID)
        try Self.assertArtifact(
            secondResult.artifact,
            requestID: secondRequest.renderRequestID,
            cursor: secondResponse.knownCursor,
            viewpoint: secondViewpoint,
            renderSettings: secondRenderSettings,
            jpegSettings: secondJPEGSettings
        )

        // An identical current-capture retry replays the byte-identical result
        // and likewise leaves the cursor at tick one.
        let replayedResponse = try Self.replayedResponse(
            from: await target.capture(secondRequest)
        )
        let replayedResult = try Self.completedCurrentCapture(
            from: replayedResponse
        )
        #expect(replayedResponse == secondResponse)
        #expect(
            replayedResult.artifact.encodedData ==
            secondResult.artifact.encodedData
        )
        #expect(replayedResponse.knownCursor == firstResponse.knownCursor)

        let thirdSequence = try #require(secondSequence.successor())
        let thirdRequestID = AgentSessionRequestID(
            sessionID: sessionID,
            sequence: thirdSequence
        )
        let thirdViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: secondViewpoint.revision.advanced(),
            camera: Camera.lookingAt(
                .zero,
                from: SIMD3<Float>(-0.5, 0.5, 8)
            )
        )
        let thirdRequest = AgentCaptureRequest(
            id: thirdRequestID,
            expectedCursor: secondResponse.knownCursor,
            stepCount: .one,
            renderRequestID: OffscreenRenderRequestID(
                rawValue: UUID(
                    uuidString: "50000000-0000-0000-0000-000000000006"
                )!
            ),
            viewpoint: thirdViewpoint,
            renderSettings: secondRenderSettings,
            jpegSettings: secondJPEGSettings
        )
        let thirdResponse = try Self.executedResponse(
            from: await target.capture(thirdRequest)
        )
        let thirdResult = try Self.completedCapture(from: thirdResponse)

        // If either current capture had advanced, this expected cursor would
        // reject. The next true advance begins at tick one and commits tick two.
        #expect(thirdResponse.requestID == thirdRequestID)
        #expect(
            thirdResult.advanceResult.initialCursor ==
            firstResponse.knownCursor
        )
        #expect(
            thirdResult.advanceResult.finalCursor ==
            firstResponse.knownCursor.advanced()
        )
        #expect(thirdResponse.knownCursor == thirdResult.advanceResult.finalCursor)
        #expect(thirdResponse.knownCursor.tick == SimulationTick(rawValue: 2))
        #expect(thirdResult.advanceResult.completedStepCount.rawValue == 1)
        try Self.assertArtifact(
            thirdResult.artifact,
            requestID: thirdRequest.renderRequestID,
            cursor: thirdResponse.knownCursor,
            viewpoint: thirdViewpoint,
            renderSettings: secondRenderSettings,
            jpegSettings: secondJPEGSettings
        )
    }

    private static func executedResponse(
        from outcome: AgentSessionSubmissionOutcome
    ) throws -> AgentSessionResponse {
        guard case let .executed(response) = outcome else {
            Issue.record("Expected executed agent response, received \(outcome)")
            throw UnexpectedOutcome()
        }
        return response
    }

    private static func replayedResponse(
        from outcome: AgentSessionSubmissionOutcome
    ) throws -> AgentSessionResponse {
        guard case let .replayed(response) = outcome else {
            Issue.record("Expected replayed agent response, received \(outcome)")
            throw UnexpectedOutcome()
        }
        return response
    }

    private static func completedCapture(
        from response: AgentSessionResponse
    ) throws -> OfflineCaptureResult {
        guard case let .capture(captureOutcome) = response.outcome else {
            Issue.record("Expected capture execution, received \(response.outcome)")
            throw UnexpectedOutcome()
        }
        guard case let .completed(result) = captureOutcome else {
            Issue.record("Expected completed capture, received \(captureOutcome)")
            throw UnexpectedOutcome()
        }
        return result
    }

    private static func completedCurrentCapture(
        from response: AgentSessionResponse
    ) throws -> OfflineCurrentCaptureResult {
        guard case let .currentCapture(captureOutcome) = response.outcome else {
            Issue.record(
                "Expected current capture execution, received \(response.outcome)"
            )
            throw UnexpectedOutcome()
        }
        guard case let .completed(result) = captureOutcome else {
            Issue.record("Expected current capture, received \(captureOutcome)")
            throw UnexpectedOutcome()
        }
        return result
    }

    private static func assertArtifact(
        _ artifact: RenderedImageArtifact,
        requestID: OffscreenRenderRequestID,
        cursor: SimulationCursor,
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        jpegSettings: JPEGEncodingSettings
    ) throws {
        #expect(artifact.format == .jpeg)
        #expect(!artifact.encodedData.isEmpty)
        #expect(Array(artifact.encodedData.prefix(2)) == [0xFF, 0xD8])
        #expect(Array(artifact.encodedData.suffix(2)) == [0xFF, 0xD9])
        #expect(artifact.sourceRequestID == requestID)
        #expect(artifact.sourceCursor == cursor)
        #expect(artifact.viewpoint == viewpoint)
        #expect(artifact.renderSettings == renderSettings)
        #expect(artifact.jpegSettings == jpegSettings)

        let source = try #require(
            CGImageSourceCreateWithData(artifact.encodedData as CFData, nil)
        )
        let typeIdentifier = try #require(CGImageSourceGetType(source))
        #expect(typeIdentifier as String == UTType.jpeg.identifier)

        let decodedImage = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        )
        #expect(decodedImage.width == renderSettings.size.width)
        #expect(decodedImage.height == renderSettings.size.height)
    }

    private struct UnexpectedOutcome: Error {}
}
