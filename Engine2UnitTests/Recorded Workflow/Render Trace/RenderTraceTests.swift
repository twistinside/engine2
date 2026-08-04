import Foundation
import simd
import Testing
@testable import Engine2

struct RenderTraceTests {
    private var contentIdentifier: RecordingContentIdentifier {
        RecordingContentIdentifier(rawValue: "engine2.render-trace-tests/v1")
    }

    @Test func schemaVersionOneRoundTripsBothProjectionChoices() throws {
        let simulationViewpointID = RenderViewpointID(
            rawValue: uuid("10000000-0000-0000-0000-000000000001")
        )
        let simulationSnapshot = snapshot(
            tick: 4,
            camera: Camera(
                position: SIMD3<Float>(1, 2, 8),
                rotation: .identity,
                projection: .perspective(
                    verticalFieldOfView: .pi / 3,
                    near: 0.1,
                    far: 250
                )
            ),
            entityPresentations: [
                EntityPresentationSnapshot(
                    id: EntityID(index: 7, generation: 2),
                    position: SIMD3<Float>(1, 2, 3),
                    rotation: simd_quatf(
                        angle: .pi / 4,
                        axis: SIMD3<Float>(0, 1, 0)
                    ),
                    scale: SIMD3<Float>(2, 3, 4),
                    meshID: .ball,
                    materialID: .goldMetalRough
                )
            ]
        )
        let explicitSnapshot = snapshot(
            tick: 5,
            camera: Camera(
                position: SIMD3<Float>(4, 3, 9),
                rotation: .identity,
                projection: .orthographic(
                    height: 12,
                    near: 0.5,
                    far: 80
                )
            ),
            entityPresentations: [
                EntityPresentationSnapshot(
                    id: EntityID(index: 9, generation: 0),
                    position: nil,
                    rotation: nil,
                    scale: nil,
                    meshID: .ball,
                    materialID: .warmDielectricSmooth
                )
            ]
        )
        let explicitViewpoint = RenderViewpoint(
            id: RenderViewpointID(
                rawValue: uuid(
                    "20000000-0000-0000-0000-000000000002"
                )
            ),
            revision: RenderViewpointRevision(rawValue: 12),
            camera: Camera(
                position: SIMD3<Float>(-4, 6, 10),
                rotation: simd_quatf(
                    angle: .pi / 6,
                    axis: SIMD3<Float>(1, 0, 0)
                ),
                projection: .perspective(
                    verticalFieldOfView: .pi / 2,
                    near: 0.25,
                    far: 500
                )
            )
        )
        let surfaceSettings = try settings(
            width: 640,
            height: 360,
            outputMode: .surface,
            exposure: 1.5
        )
        let normalSettings = try settings(
            width: 320,
            height: 240,
            outputMode: .viewSpaceNormals,
            exposure: 0
        )
        let firstClear = try RenderTraceClearColor(
            red: 0.1,
            green: 0.2,
            blue: 0.3,
            alpha: 1
        )
        let secondClear = try RenderTraceClearColor(
            red: -0.25,
            green: 1.25,
            blue: 0,
            alpha: 1
        )
        let trace = try RenderTrace(
            header: RenderTraceHeader(
                schemaVersion: RenderTrace.currentSchemaVersion,
                traceID: uuid(
                    "30000000-0000-0000-0000-000000000003"
                ),
                contentIdentifier: contentIdentifier,
                simulationCameraViewpointID: simulationViewpointID
            ),
            frames: [
                try RenderTraceFrame(
                    sequence: 10,
                    presentationSnapshot: simulationSnapshot,
                    projection: .simulationCamera,
                    settings: surfaceSettings,
                    clearColor: firstClear
                ),
                try RenderTraceFrame(
                    sequence: 20,
                    presentationSnapshot: explicitSnapshot,
                    projection: .explicit(explicitViewpoint),
                    settings: normalSettings,
                    clearColor: secondClear
                )
            ]
        )
        let encoded = try RenderTraceJSONWriter.data(for: trace)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Engine2-\(UUID().uuidString).render-trace.json"
        )
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        try RenderTraceJSONWriter.write(trace, to: url)
        let decodedData = try RenderTraceJSONReader.read(from: encoded)
        let decodedFile = try RenderTraceJSONReader.read(from: url)

        #expect(decodedData == trace)
        #expect(decodedFile == trace)
        #expect(decodedData.renderInputs[0].viewpoint.id == simulationViewpointID)
        #expect(decodedData.renderInputs[0].viewpoint.revision == .zero)
        #expect(
            decodedData.renderInputs[0].viewpoint.camera
                == simulationSnapshot.camera
        )
        #expect(decodedData.renderInputs[1].viewpoint == explicitViewpoint)
        #expect(
            decodedData.renderInputs[1].presentationSnapshot
                == explicitSnapshot
        )
        #expect(decodedData.renderInputs[1].settings == normalSettings)
        #expect(decodedData.renderInputs[1].clearColor == secondClear)
    }

    @Test func convenienceInitializerRecordsOrderedSimulationCameraFrames() throws {
        let firstSnapshot = snapshot(tick: 40)
        let secondSnapshot = snapshot(tick: 41)
        let renderSettings = try settings(
            width: 128,
            height: 64,
            outputMode: .surface,
            exposure: 2
        )
        let viewpointID = RenderViewpointID(
            rawValue: uuid("40000000-0000-0000-0000-000000000004")
        )

        let trace = try RenderTrace(
            traceID: uuid("50000000-0000-0000-0000-000000000005"),
            contentIdentifier: contentIdentifier,
            simulationCameraViewpointID: viewpointID,
            presentationSnapshots: [firstSnapshot, secondSnapshot],
            settings: renderSettings
        )

        #expect(trace.frames.map(\.sequence) == [0, 1])
        #expect(
            trace.frames.map(\.projection)
                == [.simulationCamera, .simulationCamera]
        )
        #expect(
            trace.renderInputs.map(\.presentationSnapshot)
                == [firstSnapshot, secondSnapshot]
        )
        #expect(trace.renderInputs.allSatisfy { $0.viewpoint.id == viewpointID })
        #expect(trace.renderInputs.allSatisfy { $0.settings == renderSettings })

        #expect(throws: RenderTraceValidationError.emptyFrames) {
            try RenderTrace(
                contentIdentifier: contentIdentifier,
                simulationCameraViewpointID: viewpointID,
                presentationSnapshots: [],
                settings: renderSettings
            )
        }
    }

    @Test func readerRejectsUnsupportedVersionAndOutOfOrderFrames() throws {
        let encoded = try RenderTraceJSONWriter.data(for: fixtureTrace())
        var versionObject = try jsonObject(from: encoded)
        var header = try #require(
            versionObject["header"] as? [String: Any]
        )
        header["schemaVersion"] = 2
        versionObject["header"] = header
        let unsupportedVersion = try jsonData(from: versionObject)

        #expect(
            throws: RenderTraceValidationError.unsupportedSchemaVersion(2)
        ) {
            try RenderTraceJSONReader.read(from: unsupportedVersion)
        }

        var orderObject = try jsonObject(from: encoded)
        var frames = try #require(
            orderObject["frames"] as? [[String: Any]]
        )
        frames[1]["sequence"] = frames[0]["sequence"]
        orderObject["frames"] = frames
        let outOfOrder = try jsonData(from: orderObject)

        #expect(
            throws: RenderTraceValidationError.nonincreasingFrameSequence(
                previous: 0,
                current: 0
            )
        ) {
            try RenderTraceJSONReader.read(from: outOfOrder)
        }
    }

    @Test func readerRejectsUnknownClosedVocabulary() throws {
        let encoded = try RenderTraceJSONWriter.data(for: fixtureTrace())
        var projectionObject = try jsonObject(from: encoded)
        var projectionFrames = try #require(
            projectionObject["frames"] as? [[String: Any]]
        )
        var projectionFrame = projectionFrames[0]
        var projection = try #require(
            projectionFrame["projection"] as? [String: Any]
        )
        projection["kind"] = "latestCamera"
        projectionFrame["projection"] = projection
        projectionFrames[0] = projectionFrame
        projectionObject["frames"] = projectionFrames
        let unknownProjection = try jsonData(from: projectionObject)

        do {
            _ = try RenderTraceJSONReader.read(from: unknownProjection)
            Issue.record("Expected the reader to reject an unknown projection.")
        } catch is DecodingError {
        } catch {
            Issue.record("Unexpected projection-vocabulary error: \(error)")
        }

        var object = try jsonObject(from: encoded)
        var frames = try #require(object["frames"] as? [[String: Any]])
        var firstFrame = frames[0]
        var settings = try #require(
            firstFrame["settings"] as? [String: Any]
        )
        settings["outputMode"] = "pathTraced"
        firstFrame["settings"] = settings
        frames[0] = firstFrame
        object["frames"] = frames
        let unknownOutputMode = try jsonData(from: object)

        do {
            _ = try RenderTraceJSONReader.read(from: unknownOutputMode)
            Issue.record("Expected the reader to reject an unknown output mode.")
        } catch is DecodingError {
        } catch {
            Issue.record("Unexpected unknown-vocabulary error: \(error)")
        }
    }

    @Test func headerCanBeCheckedBeforeContentOwnedPayload() throws {
        let encoded = try RenderTraceJSONWriter.data(for: fixtureTrace())
        var object = try jsonObject(from: encoded)
        var frames = try #require(object["frames"] as? [[String: Any]])
        var firstFrame = frames[0]
        var snapshot = try #require(
            firstFrame["presentationSnapshot"] as? [String: Any]
        )
        var entities = try #require(
            snapshot["entities"] as? [[String: Any]]
        )
        entities.append(
            [
                "id": [
                    "generation": 0,
                    "index": 0
                ],
                "materialID": "foreignMaterial",
                "meshID": "foreignMesh"
            ]
        )
        snapshot["entities"] = entities
        firstFrame["presentationSnapshot"] = snapshot
        frames[0] = firstFrame
        object["frames"] = frames
        let foreignPayload = try jsonData(from: object)

        let header = try RenderTraceJSONReader.readHeader(
            from: foreignPayload
        )

        #expect(header.contentIdentifier == contentIdentifier)
        do {
            _ = try RenderTraceJSONReader.read(from: foreignPayload)
            Issue.record("Expected the full reader to reject foreign content.")
        } catch is DecodingError {
        } catch {
            Issue.record("Unexpected foreign-content error: \(error)")
        }
    }

    @Test func readerRejectsMalformedQuaternionAndPixelOverflow() throws {
        let encoded = try RenderTraceJSONWriter.data(for: fixtureTrace())
        var quaternionObject = try jsonObject(from: encoded)
        var quaternionFrames = try #require(
            quaternionObject["frames"] as? [[String: Any]]
        )
        var quaternionFrame = quaternionFrames[0]
        var snapshot = try #require(
            quaternionFrame["presentationSnapshot"] as? [String: Any]
        )
        var camera = try #require(snapshot["camera"] as? [String: Any])
        camera["rotation"] = ["x": 0, "y": 0, "z": 0, "w": 0]
        snapshot["camera"] = camera
        quaternionFrame["presentationSnapshot"] = snapshot
        quaternionFrames[0] = quaternionFrame
        quaternionObject["frames"] = quaternionFrames
        let invalidQuaternion = try jsonData(from: quaternionObject)

        #expect(throws: RenderTraceValidationError.invalidQuaternion) {
            try RenderTraceJSONReader.read(from: invalidQuaternion)
        }

        var sizeObject = try jsonObject(from: encoded)
        var sizeFrames = try #require(
            sizeObject["frames"] as? [[String: Any]]
        )
        var sizeFrame = sizeFrames[0]
        var renderSettings = try #require(
            sizeFrame["settings"] as? [String: Any]
        )
        renderSettings["width"] = Int.max
        renderSettings["height"] = 2
        sizeFrame["settings"] = renderSettings
        sizeFrames[0] = sizeFrame
        sizeObject["frames"] = sizeFrames
        let overflowingSize = try jsonData(from: sizeObject)

        #expect(
            throws: RenderTraceValidationError.invalidPixelSize(
                .pixelCountOverflow(width: Int.max, height: 2)
            )
        ) {
            try RenderTraceJSONReader.read(from: overflowingSize)
        }
    }

    private func fixtureTrace() throws -> RenderTrace {
        let renderSettings = try settings(
            width: 64,
            height: 32,
            outputMode: .surface,
            exposure: 1
        )
        let firstSnapshot = snapshot(tick: 1)
        let secondSnapshot = snapshot(tick: 2)

        return try RenderTrace(
            header: RenderTraceHeader(
                schemaVersion: RenderTrace.currentSchemaVersion,
                traceID: uuid(
                    "60000000-0000-0000-0000-000000000006"
                ),
                contentIdentifier: contentIdentifier,
                simulationCameraViewpointID: RenderViewpointID(
                    rawValue: uuid(
                        "70000000-0000-0000-0000-000000000007"
                    )
                )
            ),
            frames: [
                try RenderTraceFrame(
                    sequence: 0,
                    presentationSnapshot: firstSnapshot,
                    projection: .simulationCamera,
                    settings: renderSettings
                ),
                try RenderTraceFrame(
                    sequence: 1,
                    presentationSnapshot: secondSnapshot,
                    projection: .simulationCamera,
                    settings: renderSettings
                )
            ]
        )
    }

    private func snapshot(
        tick: UInt64,
        camera: Camera = .standard,
        entityPresentations: [EntityPresentationSnapshot] = []
    ) -> SimulationPresentationSnapshot {
        SimulationPresentationSnapshot(
            cursor: SimulationCursor(
                sessionID: SimulationSessionID(
                    rawValue: uuid(
                        "80000000-0000-0000-0000-000000000008"
                    )
                ),
                tick: SimulationTick(rawValue: tick)
            ),
            camera: camera,
            entityPresentations: entityPresentations
        )
    }

    private func settings(
        width: Int,
        height: Int,
        outputMode: RenderOutputMode,
        exposure: Float
    ) throws -> OffscreenRenderSettings {
        OffscreenRenderSettings(
            size: try RenderPixelSize(width: width, height: height),
            outputMode: outputMode,
            exposure: ManualExposure(multiplier: exposure)
        )
    }

    private func jsonObject(from data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func jsonData(from object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    private func uuid(_ string: String) -> UUID {
        UUID(uuidString: string)!
    }
}
