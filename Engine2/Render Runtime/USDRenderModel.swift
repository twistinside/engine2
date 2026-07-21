import Foundation
import Metal
import MetalKit
import ModelIO

/// Renderer-owned decoded mesh data for one packaged USD model.
///
/// The value groups MetalKit meshes and exposes the unique allocations needed
/// for explicit Metal 4 residency. Game Content supplies only the abstract
/// asset reference and never receives these backend objects.
struct USDRenderModel {
    let meshes: [MTKMesh]

    /// Unique Metal allocations retained by this decoded model. The resource
    /// store decides which residency set owns their residency lifetime.
    var allocations: [any MTLAllocation] {
        var allocations: [any MTLAllocation] = []
        var addedAllocations = Set<ObjectIdentifier>()

        for mesh in meshes {
            for vertexBuffer in mesh.vertexBuffers {
                append(
                    vertexBuffer.buffer,
                    to: &allocations,
                    tracking: &addedAllocations
                )
            }

            for submesh in mesh.submeshes {
                append(
                    submesh.indexBuffer.buffer,
                    to: &allocations,
                    tracking: &addedAllocations
                )
            }
        }

        return allocations
    }

    /// Resolves every Game Content model reference into renderer-owned Metal
    /// resources. The catalog itself never receives those backend objects.
    static func load(
        catalog: RenderAssetCatalog,
        device: any MTLDevice
    ) throws -> [MeshID: USDRenderModel] {
        var models: [MeshID: USDRenderModel] = [:]

        for (meshID, asset) in catalog.models {
            models[meshID] = try load(asset, device: device)
        }

        return models
    }

    private static func load(
        _ modelAsset: ModelAssetReference,
        device: any MTLDevice
    ) throws -> USDRenderModel {
        guard let url = Bundle.main.url(
            forResource: modelAsset.resourceName,
            withExtension: modelAsset.format.rawValue
        ) else {
            throw MetalRendererError.missingModel(modelAsset.resourceName)
        }

        let allocator = MTKMeshBufferAllocator(device: device)
        let vertexDescriptor = makeVertexDescriptor()
        let modelIOAsset = MDLAsset(
            url: url,
            vertexDescriptor: vertexDescriptor,
            bufferAllocator: allocator
        )
        let meshes = try MTKMesh.newMeshes(
            asset: modelIOAsset,
            device: device
        ).metalKitMeshes
        return USDRenderModel(meshes: meshes)
    }

    /// Defines the one interleaved vertex layout shared by Model I/O and Metal.
    ///
    /// `SIMD3<Float>` has a 16-byte stride on both sides of this boundary, so
    /// explicit offsets keep the Swift descriptor aligned with `ModelVertex` in
    /// `ModelShaders.metal`. Vertex color remains in the existing decoded layout,
    /// but the explicit authored-material path does not consume it. The
    /// packaged asset is an implicit USD sphere, so requesting a normal
    /// attribute lets Model I/O's USD importer supply its generated sphere
    /// normals without introducing an engine-wide generation policy.
    static func makeVertexDescriptor() -> MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )
        vertexDescriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeColor,
            format: .float3,
            offset: MemoryLayout<SIMD3<Float>>.stride,
            bufferIndex: 0
        )
        vertexDescriptor.attributes[2] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: MemoryLayout<SIMD3<Float>>.stride * 2,
            bufferIndex: 0
        )
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(
            stride: MemoryLayout<SIMD3<Float>>.stride * 3
        )

        return vertexDescriptor
    }

    private func append(
        _ allocation: any MTLAllocation,
        to allocations: inout [any MTLAllocation],
        tracking addedAllocations: inout Set<ObjectIdentifier>
    ) {
        let identifier = ObjectIdentifier(allocation as AnyObject)

        guard addedAllocations.insert(identifier).inserted else {
            return
        }

        allocations.append(allocation)
    }
}
