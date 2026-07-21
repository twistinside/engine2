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
            catalog: RenderAssetCatalog(models: [:], materials: [:]),
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
            ],
            materials: [:]
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

                // The explicit sphere authors smooth normals that must remain
                // outward-facing through import, not merely unit length.
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

    @MainActor
    @Test func packagedSphereMaintainsAuthoredGeometryDensity() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let models = try USDRenderModel.load(
            catalog: BasicGameContent().renderAssetCatalog,
            device: device
        )
        let model = try #require(models[.ball])

        // Validate the renderer's decoded result rather than the source file.
        // Model I/O may weld seam vertices or split a USD mesh while importing,
        // but neither behavior should erase the asset's intended density.
        let decodedVertexCount = model.meshes.reduce(0) {
            $0 + $1.vertexCount
        }
        let submeshes = model.meshes.flatMap(\.submeshes)
        try #require(!submeshes.isEmpty)
        #expect(submeshes.allSatisfy { $0.primitiveType == .triangle })

        let decodedTriangleCount = submeshes.reduce(0) {
            $0 + $1.indexCount / 3
        }

        // Ball is authored as a 64 x 32 UV sphere. These floors tolerate
        // importer-specific vertex welding while preventing a regression to
        // the old low-density implicit sphere (92 vertices, 180 triangles).
        #expect(decodedVertexCount >= 1_900)
        #expect(decodedTriangleCount >= 3_800)
    }
}
