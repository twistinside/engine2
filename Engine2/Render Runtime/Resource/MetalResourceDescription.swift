//
//  MetalResourceDescription.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

import Metal

/// Device-local identity for a loaded Metal shader library.
///
/// Unlike `MeshID`, these identities are private vocabulary for the Metal
/// backend. Simulation snapshots and Game Content should not refer to them.
struct MetalShaderLibraryID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A Metal shader library ID cannot be empty.")
        self.rawValue = rawValue
    }
}

/// Device-local identity for a compiled render pipeline state.
struct MetalRenderPipelineID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A Metal render pipeline ID cannot be empty.")
        self.rawValue = rawValue
    }
}

/// Device-local identity for an immutable depth-stencil state.
struct MetalDepthStencilStateID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A Metal depth-stencil state ID cannot be empty.")
        self.rawValue = rawValue
    }
}

/// Device-local identity for a Metal 4 argument table layout.
struct MetalArgumentTableID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A Metal argument table ID cannot be empty.")
        self.rawValue = rawValue
    }
}

/// Packaged source from which the Render Runtime loads a shader library.
enum MetalShaderLibrarySource: Equatable, Sendable {
    /// The library Xcode builds from the target's `.metal` sources.
    case defaultLibrary

    /// A separately packaged precompiled Metal library.
    case bundled(resourceName: String, fileExtension: String)
}

/// Complete recipe for one Metal 4 render pipeline variant.
///
/// As new render-target formats, sample counts, vertex layouts, or function
/// constants appear, they belong in this value so a pipeline ID never silently
/// aliases incompatible state.
struct MetalRenderPipelineRecipe: Equatable, Sendable {
    let label: String
    let shaderLibraryID: MetalShaderLibraryID
    let vertexFunctionName: String
    let fragmentFunctionName: String
    let colorPixelFormat: MTLPixelFormat
    let rasterSampleCount: Int

    init(
        label: String,
        shaderLibraryID: MetalShaderLibraryID,
        vertexFunctionName: String,
        fragmentFunctionName: String,
        colorPixelFormat: MTLPixelFormat,
        rasterSampleCount: Int = 1
    ) {
        precondition(!label.isEmpty, "A Metal render pipeline label cannot be empty.")
        precondition(!vertexFunctionName.isEmpty, "A vertex function name cannot be empty.")
        precondition(!fragmentFunctionName.isEmpty, "A fragment function name cannot be empty.")
        precondition(rasterSampleCount > 0, "A render pipeline requires at least one sample.")

        self.label = label
        self.shaderLibraryID = shaderLibraryID
        self.vertexFunctionName = vertexFunctionName
        self.fragmentFunctionName = fragmentFunctionName
        self.colorPixelFormat = colorPixelFormat
        self.rasterSampleCount = rasterSampleCount
    }
}

/// Recipe for an immutable depth-stencil state.
struct MetalDepthStencilStateRecipe: Equatable, Sendable {
    let label: String
    let depthCompareFunction: MTLCompareFunction
    let isDepthWriteEnabled: Bool
}

/// Recipe for a Metal 4 argument table.
struct MetalArgumentTableRecipe: Equatable, Sendable {
    let label: String
    let maximumBufferBindingCount: Int
}

extension MetalShaderLibraryID {
    static let engine = MetalShaderLibraryID(rawValue: "engine")
}

extension MetalRenderPipelineID {
    static let model = MetalRenderPipelineID(rawValue: "model")
}

extension MetalDepthStencilStateID {
    static let disabled = MetalDepthStencilStateID(rawValue: "disabled")
}

extension MetalArgumentTableID {
    static let model = MetalArgumentTableID(rawValue: "model")
}
