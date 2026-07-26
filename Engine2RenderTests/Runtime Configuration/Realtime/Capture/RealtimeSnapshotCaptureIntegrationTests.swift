import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Engine2

struct RealtimeSnapshotCaptureIntegrationTests {
    @Test
    func capturesLivePresentationThroughMetalWithoutAdvancingSimulation() async throws {
        let gameContent = BasicGameContent()
        let configuration = RealtimeConfiguration(
            pollInterval: .seconds(60),
            catchUpPolicy: .interactive
        )
        let assembly = configuration.makeAssembly(gameContent: gameContent)
        let sourceSnapshot =
            assembly.simulationRuntime.latestPresentationSnapshot
        let sourceCursor = assembly.simulationRuntime.currentCursor
        let renderRuntime = try MetalOffscreenRenderRuntime(
            catalog: gameContent.renderAssetCatalog,
            limits: .conservative
        )
        let connection = try RealtimeSnapshotCaptureConnection(
            presentationSource: assembly.simulationRuntime,
            renderTarget: renderRuntime
        )
        let renderSize = try RenderPixelSize(width: 96, height: 64)
        let renderSettings = OffscreenRenderSettings(
            size: renderSize,
            outputMode: .surface,
            exposure: .validation
        )
        let renderRequestID = OffscreenRenderRequestID()
        let request = RealtimeSnapshotCaptureRequest(
            renderRequestID: renderRequestID,
            renderSettings: renderSettings,
            encoding: .png
        )

        let outcome = await connection.capture(request)
        guard case let .completed(selectedSnapshot, artifact) = outcome else {
            Issue.record("Expected completed live snapshot capture, received \(outcome)")
            return
        }

        #expect(selectedSnapshot == sourceSnapshot)
        #expect(assembly.simulationRuntime.currentCursor == sourceCursor)
        #expect(artifact.sourceCursor == sourceCursor)
        #expect(artifact.sourceRequestID == request.renderRequestID)
        #expect(artifact.renderSettings == renderSettings)
        #expect(artifact.encoding == .png)
        let filePrefix = Array(artifact.encodedData.prefix(8))
        #expect(
            filePrefix
                == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        )
        #expect(artifact.viewpoint.revision == .zero)
        #expect(artifact.viewpoint.camera == sourceSnapshot.camera)

        let imageSource = try #require(
            CGImageSourceCreateWithData(artifact.encodedData as CFData, nil)
        )
        let typeIdentifier = try #require(CGImageSourceGetType(imageSource))
        #expect(typeIdentifier as String == UTType.png.identifier)

        let image = try #require(
            CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        )
        #expect(image.width == renderSettings.size.width)
        #expect(image.height == renderSettings.size.height)
    }
}
