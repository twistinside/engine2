import Metal
@testable import Engine2

/// Stable domain-frame factory shared by renderer benchmark tests.
///
/// The fixture uses the production example catalog and its packaged model so
/// integration tests exercise exact resource resolution rather than a
/// benchmark-only shader or geometry path.
struct RenderBenchmarkTestFixture {
    let sessionID = SimulationSessionID()
    let viewpointID = RenderViewpointID()
    let pixelSize: RenderPixelSize

    var catalog: RenderAssetCatalog {
        .everything
    }

    init(width: Int = 64, height: Int = 64) throws {
        self.pixelSize = try RenderPixelSize(
            width: width,
            height: height
        )
    }

    func frame(
        sequence: UInt64,
        tick: UInt64,
        size: RenderPixelSize? = nil,
        clearColor: MTLClearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )
    ) -> RenderBenchmarkFrame {
        let camera = Camera.standard
        let snapshot = SimulationPresentationSnapshot(
            cursor: SimulationCursor(
                sessionID: sessionID,
                tick: SimulationTick(rawValue: tick)
            ),
            camera: camera,
            entityPresentations: [
                EntityPresentationSnapshot(
                    id: EntityID(index: 0, generation: 0),
                    position: .zero,
                    rotation: nil,
                    scale: nil,
                    meshID: .ball,
                    materialID: .warmDielectric
                )
            ]
        )
        let viewpoint = RenderViewpoint(
            id: viewpointID,
            revision: RenderViewpointRevision(rawValue: tick),
            camera: camera
        )
        let settings = OffscreenRenderSettings(
            size: size ?? pixelSize,
            outputMode: .surface,
            exposure: .validation
        )
        return RenderBenchmarkFrame(
            sequence: sequence,
            presentationSnapshot: snapshot,
            viewpoint: viewpoint,
            settings: settings,
            clearColor: clearColor
        )
    }
}
