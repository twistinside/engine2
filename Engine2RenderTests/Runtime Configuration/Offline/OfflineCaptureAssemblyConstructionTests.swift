import CoreGraphics
import Foundation
import ImageIO
import simd
import Testing
import UniformTypeIdentifiers
@testable import Engine2
@testable import BasicGameContent
@testable import Engine2OfflineCaptureAssembly

struct OfflineCaptureAssemblyConstructionTests {
    @Test
    func gameContentConstructionCreatesAReadyClosedAssembly() throws {
        let assembly = try OfflineCaptureAssembly(
            gameContent: BasicGameContent()
        )

        #expect(assembly.initialCursor.tick == .zero)
        _ = assembly.body
    }

    @Test
    func composesSimulationMetalAndImageArtifactsAcrossCaptures() async throws {
        let sessionID = SimulationSessionID(
            rawValue: UUID(
                uuidString: "40000000-0000-0000-0000-000000000001"
            )!
        )
        let assembly = try OfflineCaptureAssembly(
            gameContent: BasicGameContent(),
            renderLimits: .conservative,
            sessionID: sessionID
        )
        let captureTarget = assembly.captureTarget

        let viewpointID = RenderViewpointID(
            rawValue: UUID(
                uuidString: "40000000-0000-0000-0000-000000000002"
            )!
        )
        let firstViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: RenderViewpointRevision(rawValue: 7),
            camera: Camera.lookingAt(
                .zero,
                from: SIMD3<Float>(0, 0, 8),
                up: SIMD3<Float>(0, 1, 0),
                projection: .standardPerspective
            )
        )
        let firstRenderSettings = OffscreenRenderSettings(
            size: try RenderPixelSize(width: 96, height: 64),
            outputMode: .surface,
            exposure: .validation
        )
        let firstEncoding = ImageArtifactEncoding.jpeg(
            quality: try JPEGQuality(0.72)
        )
        let firstRequest = OfflineCaptureRequest(
            advanceRequest: SimulationAdvanceRequest(
                expectedCursor: assembly.initialCursor,
                stepCount: .one,
                inputAssignment: .none
            ),
            renderRequestID: OffscreenRenderRequestID(
                rawValue: UUID(
                    uuidString: "40000000-0000-0000-0000-000000000003"
                )!
            ),
            viewpoint: firstViewpoint,
            renderSettings: firstRenderSettings,
            encoding: firstEncoding
        )

        // The public assembly boundary performs real fixed-step Simulation,
        // real Metal offscreen submission/readback, then real Image I/O
        // derivation without exposing any concrete Runtime references.
        let firstResult = try completedResult(
            from: await captureTarget.capture(firstRequest)
        )

        #expect(
            firstResult.advanceResult.initialCursor == assembly.initialCursor
        )
        #expect(firstResult.advanceResult.initialCursor.sessionID == sessionID)
        #expect(firstResult.advanceResult.initialCursor.tick == .zero)
        #expect(
            firstResult.advanceResult.finalCursor
                == assembly.initialCursor.advanced()
        )
        #expect(firstResult.advanceResult.completedStepCount.rawValue == 1)
        #expect(
            firstResult.advanceResult.finalPresentationSnapshot.cursor
                == firstResult.advanceResult.finalCursor
        )
        try assertArtifact(
            firstResult.artifact,
            requestID: firstRequest.renderRequestID,
            cursor: firstResult.advanceResult.finalCursor,
            viewpoint: firstViewpoint,
            renderSettings: firstRenderSettings,
            encoding: firstEncoding
        )

        let secondViewpoint = RenderViewpoint(
            id: viewpointID,
            revision: firstViewpoint.revision.advanced(),
            camera: Camera.lookingAt(
                .zero,
                from: SIMD3<Float>(1, 0.5, 8),
                up: SIMD3<Float>(0, 1, 0),
                projection: .standardPerspective
            )
        )
        let secondRenderSettings = OffscreenRenderSettings(
            size: try RenderPixelSize(width: 80, height: 60),
            outputMode: .viewSpaceNormals,
            exposure: ManualExposure(multiplier: 1.25)
        )
        let secondEncoding = ImageArtifactEncoding.png
        let secondRequest = OfflineCaptureRequest(
            advanceRequest: SimulationAdvanceRequest(
                expectedCursor: firstResult.advanceResult.finalCursor,
                stepCount: SimulationStepCount(rawValue: 2),
                inputAssignment: .none
            ),
            renderRequestID: OffscreenRenderRequestID(
                rawValue: UUID(
                    uuidString: "40000000-0000-0000-0000-000000000004"
                )!
            ),
            viewpoint: secondViewpoint,
            renderSettings: secondRenderSettings,
            encoding: secondEncoding
        )

        let secondResult = try completedResult(
            from: await captureTarget.capture(secondRequest)
        )

        // The first outcome is the only cursor authority needed to issue the
        // next request. No hidden Runtime read or latest-value sample is used.
        #expect(
            secondResult.advanceResult.initialCursor
                == firstResult.advanceResult.finalCursor
        )
        #expect(
            secondResult.advanceResult.initialCursor.tick
                == SimulationTick(rawValue: 1)
        )
        #expect(
            secondResult.advanceResult.finalCursor.tick
                == SimulationTick(rawValue: 3)
        )
        #expect(secondResult.advanceResult.finalCursor.sessionID == sessionID)
        #expect(secondResult.advanceResult.completedStepCount.rawValue == 2)
        #expect(
            secondResult.advanceResult.finalPresentationSnapshot.cursor
                == secondResult.advanceResult.finalCursor
        )
        try assertArtifact(
            secondResult.artifact,
            requestID: secondRequest.renderRequestID,
            cursor: secondResult.advanceResult.finalCursor,
            viewpoint: secondViewpoint,
            renderSettings: secondRenderSettings,
            encoding: secondEncoding
        )

        #expect(
            secondResult.artifact.sourceRequestID
                != firstResult.artifact.sourceRequestID
        )
        #expect(
            secondResult.artifact.sourceCursor
                != firstResult.artifact.sourceCursor
        )
        #expect(
            secondResult.artifact.viewpoint.id
                == firstResult.artifact.viewpoint.id
        )
        #expect(
            secondResult.artifact.viewpoint.revision
                != firstResult.artifact.viewpoint.revision
        )
    }

    private func completedResult(from outcome: OfflineCaptureOutcome) throws -> OfflineCaptureResult {
        guard case let .completed(result) = outcome else {
            Issue.record("Expected completed offline capture, received \(outcome)")
            throw UnexpectedOutcome()
        }
        return result
    }

    private func assertArtifact(
        _ artifact: RenderedImageArtifact,
        requestID: OffscreenRenderRequestID,
        cursor: SimulationCursor,
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        encoding: ImageArtifactEncoding
    ) throws {
        #expect(!artifact.encodedData.isEmpty)
        #expect(artifact.sourceRequestID == requestID)
        #expect(artifact.sourceCursor == cursor)
        #expect(artifact.viewpoint == viewpoint)
        #expect(artifact.viewpoint.id == viewpoint.id)
        #expect(artifact.viewpoint.revision == viewpoint.revision)
        #expect(artifact.viewpoint.camera == viewpoint.camera)
        #expect(artifact.renderSettings == renderSettings)
        #expect(artifact.encoding == encoding)

        let expectedType: UTType
        switch encoding {
        case .jpeg:
            expectedType = .jpeg
            #expect(Array(artifact.encodedData.prefix(2)) == [0xFF, 0xD8])
            #expect(Array(artifact.encodedData.suffix(2)) == [0xFF, 0xD9])
        case .png:
            expectedType = .png
            #expect(
                Array(artifact.encodedData.prefix(8))
                    == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
            )
        }
        let source = try #require(
            CGImageSourceCreateWithData(artifact.encodedData as CFData, nil)
        )
        let typeIdentifier = try #require(CGImageSourceGetType(source))
        #expect(typeIdentifier as String == expectedType.identifier)

        let decodedImage = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        )
        #expect(decodedImage.width == renderSettings.size.width)
        #expect(decodedImage.height == renderSettings.size.height)
    }

    private struct UnexpectedOutcome: Error {}
}
