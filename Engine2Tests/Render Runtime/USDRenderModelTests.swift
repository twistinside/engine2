import Metal
import MetalKit
import ModelIO
import simd
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
                .ball: ModelAssetReference(
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

    @MainActor
    @Test func packagedSphereDecodesInterleavedUnitNormalsForEveryMesh() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let models = try USDRenderModel.load(
            catalog: BasicGameContent().renderAssetCatalog,
            device: device
        )
        let model = try #require(models[.ball])
        try #require(!model.meshes.isEmpty)

        // Production renders every mesh produced by the importer, so validate
        // the complete decoded model rather than assuming the asset will remain
        // a single mesh forever.
        for mesh in model.meshes {
            let position = try #require(
                mesh.vertexDescriptor.attributes[0] as? MDLVertexAttribute
            )
            let color = try #require(
                mesh.vertexDescriptor.attributes[1] as? MDLVertexAttribute
            )
            let normal = try #require(
                mesh.vertexDescriptor.attributes[2] as? MDLVertexAttribute
            )
            let layout = try #require(
                mesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout
            )
            let vertexBuffer = try #require(mesh.vertexBuffers.first)

            #expect(mesh.vertexCount > 0)
            #expect(mesh.vertexBuffers.count == 1)
            #expect(position.name == MDLVertexAttributePosition)
            #expect(position.format == .float3)
            #expect(position.offset == 0)
            #expect(position.bufferIndex == 0)
            #expect(color.name == MDLVertexAttributeColor)
            #expect(color.format == .float3)
            #expect(color.offset == MemoryLayout<SIMD3<Float>>.stride)
            #expect(color.bufferIndex == 0)
            #expect(normal.name == MDLVertexAttributeNormal)
            #expect(normal.format == .float3)
            #expect(normal.offset == MemoryLayout<SIMD3<Float>>.stride * 2)
            #expect(normal.bufferIndex == 0)
            #expect(layout.stride == MemoryLayout<SIMD3<Float>>.stride * 3)

            // The production descriptor interleaves three 16-byte SIMD3 slots.
            // Prove the imported MetalKit buffer is CPU-addressable and large
            // enough before reading it; `MTLBuffer.contents()` is unavailable
            // for private storage and must never be dereferenced in that case.
            try #require(vertexBuffer.buffer.storageMode != .private)
            let requiredByteCount = mesh.vertexCount * layout.stride
            try #require(requiredByteCount <= vertexBuffer.length)
            try #require(
                vertexBuffer.offset + requiredByteCount
                    <= vertexBuffer.buffer.length
            )
            try #require(
                vertexBuffer.offset.isMultiple(
                    of: MemoryLayout<SIMD3<Float>>.alignment
                )
            )
            let vertices = vertexBuffer.buffer.contents()
                .advanced(by: vertexBuffer.offset)
                .assumingMemoryBound(to: SIMD3<Float>.self)

            for vertexIndex in 0..<mesh.vertexCount {
                let vertexBase = vertexIndex * 3
                let decodedPosition = vertices[vertexBase]
                let decodedNormal = vertices[vertexBase + 2]
                let normalLength = simd_length(decodedNormal)

                #expect(decodedNormal.x.isFinite)
                #expect(decodedNormal.y.isFinite)
                #expect(decodedNormal.z.isFinite)
                #expect(abs(normalLength - 1) < 0.0001)

                // Ball.usdz contains an implicit sphere. Model I/O-generated
                // normals must point outward, not merely have unit length.
                if simd_length(decodedPosition) > 0 {
                    #expect(
                        simd_dot(
                            simd_normalize(decodedPosition),
                            decodedNormal
                        ) > 0.98
                    )
                }
            }
        }
    }
}
