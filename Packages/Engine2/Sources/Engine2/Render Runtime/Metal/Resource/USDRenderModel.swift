import Engine2GPUABI
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

    /// Whether every indexed draw visited by the frame encoder has complete,
    /// usable geometry, proved once when the immutable model is constructed.
    ///
    /// The production encoder binds only the first vertex buffer of each mesh
    /// and emits indexed draws for its submeshes. Exact rendering uses this
    /// proof during preparation so a decoded-but-empty or partially
    /// malformed model is distinct from a missing model. Requiring every mesh
    /// and submesh prevents an exact result from silently omitting only part of
    /// a decoded asset; live screen rendering remains free to tolerate it.
    let hasCompleteDrawableIndexedGeometry: Bool

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

    init(meshes: [MTKMesh]) {
        self.meshes = meshes
        guard !meshes.isEmpty else {
            self.hasCompleteDrawableIndexedGeometry = false
            return
        }

        self.hasCompleteDrawableIndexedGeometry = meshes.allSatisfy { mesh in
            guard let vertexBuffer = mesh.vertexBuffers.first,
                  vertexBuffer.containsUsableBytes(minimumByteCount: 1),
                  !mesh.submeshes.isEmpty
            else {
                return false
            }

            return mesh.submeshes.allSatisfy { submesh in
                guard submesh.indexCount > 0,
                      let requiredByteCount = submesh.requiredIndexByteCount
                else {
                    return false
                }

                return submesh.indexBuffer.containsUsableBytes(minimumByteCount: requiredByteCount)
            }
        }
    }

    /// Resolves every Game Content model reference into renderer-owned Metal
    /// resources. The catalog itself never receives those backend objects.
    static func load(catalog: RenderAssetCatalog, device: any MTLDevice) throws -> [MeshAssetKey: USDRenderModel] {
        var models: [MeshAssetKey: USDRenderModel] = [:]

        for (meshID, asset) in catalog.models {
            models[meshID] = try load(asset, device: device)
        }

        return models
    }

    private static func load(_ modelAsset: ModelAssetReference, device: any MTLDevice) throws -> USDRenderModel {
        guard FileManager.default.fileExists(
            atPath: modelAsset.resourceURL.path(percentEncoded: false)
        ) else {
            throw MetalRendererError.missingModel(modelAsset)
        }

        let allocator = MTKMeshBufferAllocator(device: device)
        let vertexDescriptor = makeVertexDescriptor()
        let modelIOAsset = MDLAsset(
            url: modelAsset.resourceURL,
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
    /// The imported `ModelVertex` declaration supplies offsets and stride, so
    /// this descriptor and the model shader compile one raw layout. Vertex color
    /// remains in the decoded record, but the explicit authored-material path
    /// does not consume it. The packaged sphere authors smooth outward normals
    /// alongside its explicit polygonal geometry. This descriptor preserves
    /// those normals without introducing an engine-wide generation policy.
    static func makeVertexDescriptor() -> MDLVertexDescriptor {
        guard
            let positionOffset = MemoryLayout<ModelVertex>.offset(
                of: \.position
            ),
            let colorOffset = MemoryLayout<ModelVertex>.offset(of: \.color),
            let normalOffset = MemoryLayout<ModelVertex>.offset(of: \.normal)
        else {
            preconditionFailure(
                "The imported model-vertex record must have a fixed layout."
            )
        }

        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: positionOffset,
            bufferIndex: 0
        )
        vertexDescriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeColor,
            format: .float3,
            offset: colorOffset,
            bufferIndex: 0
        )
        vertexDescriptor.attributes[2] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: normalOffset,
            bufferIndex: 0
        )
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(
            stride: MemoryLayout<ModelVertex>.stride
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
