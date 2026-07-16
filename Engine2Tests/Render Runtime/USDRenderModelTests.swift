//
//  USDRenderModelTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

import Metal
import Testing
@testable import Engine2

struct USDRenderModelTests {
    @MainActor
    @Test func emptyCatalogResolvesToNoBackendModels() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())

        let models = try USDRenderModel.load(
            catalog: RenderAssetCatalog(models: [:]),
            device: device
        )

        #expect(models.isEmpty)
    }

    @MainActor
    @Test func missingPackagedModelReportsAnError() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let catalog = RenderAssetCatalog(
            models: [
                MeshID(rawValue: "missing"): ModelAssetReference(
                    resourceName: "ModelThatDoesNotExist",
                    format: .usdz
                )
            ]
        )

        do {
            _ = try USDRenderModel.load(catalog: catalog, device: device)
            Issue.record("Expected a missing packaged model to throw an error.")
        } catch {
            // Any error is sufficient here because the renderer's concrete
            // backend error vocabulary is intentionally private.
        }
    }
}
