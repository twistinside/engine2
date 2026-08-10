import simd
import Testing
@testable import Engine2

struct GPUPlanetInstanceTests {
    private let description = TerrestrialPlanetDescription(
        elevationTextureID: .terrestrialPlanetElevation,
        surfaceTextureID: .terrestrialPlanetSurface,
        controlTextureID: .terrestrialPlanetControl,
        cloudTextureID: .terrestrialPlanetClouds,
        surfaceRadius: 1,
        maximumRelief: 0.035,
        seaLevel: 0.5,
        cloudRadius: 1.05,
        atmosphereRadius: 1.10,
        cloudOpacity: 0.82,
        atmosphereIntensity: 0.75,
        cloudShadowStrength: 0.65
    )

    @Test func sharedLayoutContainsTransformsAndFourPlanetLanes() {
        #expect(MemoryLayout<GPUPlanetInstance>.alignment == 16)
        #expect(MemoryLayout<GPUPlanetInstance>.size == 240)
        #expect(MemoryLayout<GPUPlanetInstance>.stride == 240)
        #expect(
            MemoryLayout<GPUPlanetInstance>.offset(
                of: \.modelViewProjectionMatrix
            ) == 0
        )
        #expect(
            MemoryLayout<GPUPlanetInstance>.offset(of: \.modelViewMatrix)
                == 64
        )
        #expect(
            MemoryLayout<GPUPlanetInstance>.offset(of: \.normalMatrix)
                == 128
        )
        #expect(
            MemoryLayout<GPUPlanetInstance>.offset(
                of: \.surfaceReliefSeaCloudRadii
            ) == 176
        )
        #expect(
            MemoryLayout<GPUPlanetInstance>.offset(
                of: \.atmosphereCloudParameters
            ) == 192
        )
        #expect(
            MemoryLayout<GPUPlanetInstance>.offset(
                of: \.directionToLightViewPadding
            ) == 208
        )
        #expect(
            MemoryLayout<GPUPlanetInstance>.offset(
                of: \.directionToLightLocalPadding
            ) == 224
        )
    }

    @Test func packsTransformsAppearanceAndProofLight() throws {
        let camera = Camera.standard
        let projectionMatrix = camera.projectionMatrix(aspectRatio: 16 / 9)
        let renderInstance = try projectedInstance(
            transform: .identity,
            camera: camera
        )
        let packed = GPUPlanetInstance(
            renderInstance,
            description: description,
            projectionMatrix: projectionMatrix,
            camera: camera
        )

        #expect(
            packed.modelViewProjectionMatrix ==
                projectionMatrix * renderInstance.modelViewMatrix
        )
        #expect(packed.modelViewMatrix == renderInstance.modelViewMatrix)
        #expect(packed.normalMatrix == renderInstance.normalMatrix)
        #expect(
            packed.surfaceReliefSeaCloudRadii ==
                SIMD4<Float>(1, 0.035, 0.5, 1.05)
        )
        #expect(
            packed.atmosphereCloudParameters ==
                SIMD4<Float>(1.10, 0.82, 0.75, 0.65)
        )

        let directionToLightView = SIMD3<Float>(
            packed.directionToLightViewPadding.x,
            packed.directionToLightViewPadding.y,
            packed.directionToLightViewPadding.z
        )
        let directionToLightLocal = SIMD3<Float>(
            packed.directionToLightLocalPadding.x,
            packed.directionToLightLocalPadding.y,
            packed.directionToLightLocalPadding.z
        )
        #expect(
            simd_distance(
                directionToLightView,
                GPUPlanetInstance.proofDirectionToLightWorld
            ) < 0.0001
        )
        #expect(
            simd_distance(
                directionToLightLocal,
                GPUPlanetInstance.proofDirectionToLightWorld
            ) < 0.0001
        )
        #expect(packed.directionToLightViewPadding.w == 0)
        #expect(packed.directionToLightLocalPadding.w == 0)
    }

    @Test func rotationsTransformProofLightWithoutTranslationLeakage() throws {
        let transform = Transform(
            position: SIMD3<Float>(13, -7, 5),
            rotation: simd_quatf(
                angle: .pi / 3,
                axis: simd_normalize(SIMD3<Float>(1, 2, 0))
            ),
            scale: SIMD3<Float>(repeating: 2)
        )
        let camera = Camera(
            position: SIMD3<Float>(-19, 11, 23),
            rotation: simd_quatf(
                angle: -.pi / 4,
                axis: SIMD3<Float>(0, 1, 0)
            ),
            projection: .standardPerspective
        )
        let renderInstance = try projectedInstance(
            transform: transform,
            camera: camera
        )
        let packed = GPUPlanetInstance(
            renderInstance,
            description: description,
            projectionMatrix: camera.projectionMatrix(aspectRatio: 1),
            camera: camera
        )
        let actualViewDirection = SIMD3<Float>(
            packed.directionToLightViewPadding.x,
            packed.directionToLightViewPadding.y,
            packed.directionToLightViewPadding.z
        )
        let actualLocalDirection = SIMD3<Float>(
            packed.directionToLightLocalPadding.x,
            packed.directionToLightLocalPadding.y,
            packed.directionToLightLocalPadding.z
        )
        let expectedViewDirection = simd_normalize(
            simd_float3x3(camera.rotation.inverse)
                * GPUPlanetInstance.proofDirectionToLightWorld
        )
        let expectedLocalDirection = simd_normalize(
            simd_float3x3(transform.rotation.inverse)
                * GPUPlanetInstance.proofDirectionToLightWorld
        )

        #expect(
            simd_distance(actualViewDirection, expectedViewDirection) < 0.0001
        )
        #expect(
            simd_distance(actualLocalDirection, expectedLocalDirection) < 0.0001
        )
        #expect(abs(simd_length(actualViewDirection) - 1) < 0.0001)
        #expect(abs(simd_length(actualLocalDirection) - 1) < 0.0001)
    }

    private func projectedInstance(
        transform: Transform,
        camera: Camera
    ) throws -> RenderInstance {
        let presentation = EntityPresentationSnapshot(
            id: EntityID(index: 0, generation: 0),
            position: transform.position,
            rotation: transform.rotation,
            scale: transform.scale,
            meshID: .terrestrialPlanet,
            materialID: .terrestrialPlanet
        )
        return try RenderInstance(
            projecting: presentation,
            viewMatrix: camera.viewMatrix
        )
    }
}
