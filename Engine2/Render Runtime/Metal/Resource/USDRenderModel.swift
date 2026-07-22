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
    /// usable geometry.
    ///
    /// The production encoder binds only the first vertex buffer of each mesh
    /// and emits indexed draws for its submeshes. Exact rendering uses this
    /// predicate during preparation so a decoded-but-empty or partially
    /// malformed model is distinct from a missing model. Requiring every mesh
    /// and submesh prevents an exact result from silently omitting only part of
    /// a decoded asset; live screen rendering remains free to tolerate it.
    var hasCompleteDrawableIndexedGeometry: Bool {
        guard !meshes.isEmpty else {
            return false
        }

        return meshes.allSatisfy { mesh in
            guard let vertexBuffer = mesh.vertexBuffers.first,
                  Self.containsUsableBytes(vertexBuffer, minimumByteCount: 1),
                  !mesh.submeshes.isEmpty
            else {
                return false
            }

            return mesh.submeshes.allSatisfy { submesh in
                guard submesh.indexCount > 0,
                      let requiredByteCount = Self.requiredIndexByteCount(
                        for: submesh
                      )
                else {
                    return false
                }

                return Self.containsUsableBytes(
                    submesh.indexBuffer,
                    minimumByteCount: requiredByteCount
                )
            }
        }
    }

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
    /// packaged sphere authors smooth outward normals alongside its explicit
    /// polygonal geometry. This descriptor preserves those normals without
    /// introducing an engine-wide runtime generation policy.
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

    /// Computes the byte range consumed by one indexed draw without allowing
    /// malformed counts to overflow into an apparently small buffer request.
    private static func requiredIndexByteCount(
        for submesh: MTKSubmesh
    ) -> Int? {
        let bytesPerIndex: Int
        switch submesh.indexType {
        case .uint16:
            bytesPerIndex = MemoryLayout<UInt16>.stride

        case .uint32:
            bytesPerIndex = MemoryLayout<UInt32>.stride

        @unknown default:
            return nil
        }

        let result = submesh.indexCount.multipliedReportingOverflow(
            by: bytesPerIndex
        )
        return result.overflow ? nil : result.partialValue
    }

    /// Proves the MetalKit slice contains the bytes the encoder will address.
    private static func containsUsableBytes(
        _ meshBuffer: MTKMeshBuffer,
        minimumByteCount: Int
    ) -> Bool {
        guard minimumByteCount > 0,
              meshBuffer.offset >= 0,
              meshBuffer.length >= minimumByteCount
        else {
            return false
        }

        let sliceEnd = meshBuffer.offset.addingReportingOverflow(
            meshBuffer.length
        )
        return !sliceEnd.overflow
            && sliceEnd.partialValue <= meshBuffer.buffer.length
    }
}
