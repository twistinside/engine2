//
//  MetalResourceDescriptionTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

import Testing
@testable import Engine2

struct MetalResourceDescriptionTests {
    @Test func backendResourceIdentitiesRemainDistinct() {
        #expect(MetalShaderLibraryID.engine.rawValue == "engine")
        #expect(MetalRenderPipelineID.model.rawValue == "model")
        #expect(MetalDepthStencilStateID.disabled.rawValue == "disabled")
        #expect(MetalArgumentTableID.model.rawValue == "model")

        #expect(
            MetalRenderPipelineID(rawValue: "model") !=
                MetalRenderPipelineID(rawValue: "shadow")
        )
    }
}
