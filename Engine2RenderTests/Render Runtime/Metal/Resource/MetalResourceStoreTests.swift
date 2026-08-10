import Metal
import Testing
@testable import Engine2

struct MetalResourceStoreTests {
    @Test func ownsMetal4CompilerQueueAndRequiredStateLibraries() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: MetalResourceStore.defaultFrameCount
        )

        #expect(store.frames.count == MetalResourceStore.defaultFrameCount)

        let requiredResources = store.requiredResources
        let library = requiredResources.engineLibrary
        let pbrPipeline = requiredResources.modelPBRPipeline
        let normalPipeline = requiredResources.modelNormalDiagnosticPipeline
        let planetSurfacePipeline = requiredResources.terrestrialPlanetSurfacePipeline
        let planetNormalPipeline = requiredResources.terrestrialPlanetNormalDiagnosticPipeline
        let planetCloudPipeline = requiredResources.terrestrialPlanetCloudPipeline
        let planetAtmospherePipeline = requiredResources.terrestrialPlanetAtmospherePipeline
        let toneMappedPresentationPipeline = requiredResources.hdrToneMappedPresentationPipeline
        let linearPresentationPipeline = requiredResources.linearPresentationPipeline
        let depthStencil = requiredResources.opaqueDepthStencilState
        let translucentDepthStencil = requiredResources.translucentDepthStencilState
        let modelArgumentTable = requiredResources.modelArgumentTable
        let pbrSceneArgumentTable = requiredResources.pbrSceneArgumentTable
        let planetArgumentTable = requiredResources.terrestrialPlanetArgumentTable
        let planetSampler = requiredResources.terrestrialPlanetSamplerState
        let presentationArgumentTable = requiredResources.hdrPresentationArgumentTable

        #expect(store.device.registryID == device.registryID)
        #expect(store.compiler.device.registryID == device.registryID)

        // Every entry point required by both render phases must live in the
        // eagerly loaded engine library. A missing function therefore fails
        // store construction rather than first appearing in the draw path.
        #expect(library.functionNames.contains("modelVertex"))
        #expect(library.functionNames.contains("modelPBRFragment"))
        #expect(library.functionNames.contains("modelNormalDiagnosticFragment"))
        #expect(library.functionNames.contains("terrestrialPlanetSurfaceVertex"))
        #expect(library.functionNames.contains("terrestrialPlanetSurfaceFragment"))
        #expect(
            library.functionNames.contains(
                "terrestrialPlanetNormalDiagnosticFragment"
            )
        )
        #expect(library.functionNames.contains("terrestrialPlanetCloudVertex"))
        #expect(library.functionNames.contains("terrestrialPlanetCloudFragment"))
        #expect(
            library.functionNames.contains(
                "terrestrialPlanetAtmosphereVertex"
            )
        )
        #expect(
            library.functionNames.contains(
                "terrestrialPlanetAtmosphereFragment"
            )
        )
        #expect(library.functionNames.contains("hdrPresentationVertex"))
        #expect(
            library.functionNames.contains(
                "hdrToneMappedPresentationFragment"
            )
        )
        #expect(library.functionNames.contains("linearPresentationFragment"))

        // Scene pipelines compile against linear HDR color, while the two
        // presentation pipelines compile against the sRGB drawable format.
        // Successful eager compilation plus these closed identities protects
        // that split even though pipeline state hides its source descriptor.
        #expect(pbrPipeline.label == "USD Model PBR Pipeline")
        #expect(normalPipeline.label == "USD Model Normal Diagnostic Pipeline")
        #expect(
            planetSurfacePipeline.label ==
                "Terrestrial Planet Surface Pipeline"
        )
        #expect(
            planetNormalPipeline.label ==
                "Terrestrial Planet Normal Diagnostic Pipeline"
        )
        #expect(
            planetCloudPipeline.label ==
                "Terrestrial Planet Cloud Pipeline"
        )
        #expect(
            planetAtmospherePipeline.label ==
                "Terrestrial Planet Atmosphere Pipeline"
        )
        #expect(
            toneMappedPresentationPipeline.label ==
                "HDR Tone-Mapped Presentation Pipeline"
        )
        #expect(
            linearPresentationPipeline.label ==
                "Linear Diagnostic Presentation Pipeline"
        )
        #expect(depthStencil.label == "Opaque Depth")
        #expect(
            translucentDepthStencil.label ==
                "Translucent Read-Only Depth"
        )

        // Each phase uses only the binding vocabulary it owns: model geometry,
        // shared scene constants, planet maps, or HDR presentation inputs.
        #expect(modelArgumentTable.label == "USD Mesh Argument Table")
        #expect(pbrSceneArgumentTable.label == "PBR Scene Argument Table")
        #expect(planetArgumentTable.label == "Terrestrial Planet Argument Table")
        #expect(
            planetSampler.label ==
                "Terrestrial Planet Equirectangular Sampler"
        )
        #expect(
            presentationArgumentTable.label ==
                "HDR Presentation Argument Table"
        )
    }

    @Test func requiredSetRetainsTheExactEngineLibrary() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: .materialOnlyTestCatalog,
            frameCount: MetalResourceStore.defaultFrameCount
        )

        let first = store.requiredResources.engineLibrary
        let second = store.requiredResources.engineLibrary

        #expect(first as AnyObject === second as AnyObject)
    }

    @Test func retainsExactAuthoredMaterialDescriptions() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let catalog = BasicGameContent().renderAssetCatalog
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: catalog,
            frameCount: MetalResourceStore.defaultFrameCount
        )

        // Material identities cross the runtime boundary. Render retains each
        // authored description and its privately resolved planet maps while a
        // frame packs the selected material into private instance data.
        for (materialID, expected) in catalog.materials {
            #expect(
                store.renderMaterialDescription(for: materialID)
                    == .opaquePBR(expected)
            )
        }

        for (materialID, expected) in catalog.terrestrialPlanets {
            #expect(
                store.renderMaterialDescription(for: materialID)
                    == .terrestrialPlanet(expected)
            )
            #expect(
                store.terrestrialPlanetResources(for: materialID)?.description
                    == expected
            )
        }
    }

    @Test func resolvesAuthoredPlanetMapsWithExactGPUContracts() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let catalog = BasicGameContent().renderAssetCatalog
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: catalog,
            frameCount: 1
        )
        let planet = try #require(
            store.terrestrialPlanetResources(for: .terrestrialPlanet)
        )

        for (textureID, reference) in catalog.textures {
            let texture = try #require(store.texture(for: textureID))

            #expect(texture.width == 1_024)
            #expect(texture.height == 512)
            #expect(texture.mipmapLevelCount == 11)
            switch textureID {
            case .terrestrialPlanetElevation:
                #expect(texture.pixelFormat == .r16Unorm)
            case .terrestrialPlanetSurface:
                #expect(
                    [.rgba8Unorm_srgb, .bgra8Unorm_srgb].contains(
                        texture.pixelFormat
                    )
                )
            case .terrestrialPlanetControl, .terrestrialPlanetClouds:
                #expect(
                    [.rgba8Unorm, .bgra8Unorm].contains(texture.pixelFormat)
                )
            }
            #expect(texture.storageMode == .private)
            #expect(texture.usage.contains(.shaderRead))
            #expect(texture.label == reference.resourceURL.lastPathComponent)
        }

        let elevationTexture = try #require(
            store.texture(for: .terrestrialPlanetElevation)
        )
        let surfaceTexture = try #require(
            store.texture(for: .terrestrialPlanetSurface)
        )
        let controlTexture = try #require(
            store.texture(for: .terrestrialPlanetControl)
        )
        let cloudTexture = try #require(
            store.texture(for: .terrestrialPlanetClouds)
        )
        #expect(
            planet.elevationTexture as AnyObject ===
                elevationTexture as AnyObject
        )
        #expect(
            planet.surfaceTexture as AnyObject ===
                surfaceTexture as AnyObject
        )
        #expect(
            planet.controlTexture as AnyObject ===
                controlTexture as AnyObject
        )
        #expect(
            planet.cloudTexture as AnyObject ===
                cloudTexture as AnyObject
        )
    }

    @Test func rejectsIncompleteMaterialContentBeforeBuildingTheStore() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let warmDielectric = try #require(
            BasicGameContent().renderAssetCatalog.materials[.warmDielectric]
        )
        let incompleteCatalog = RenderAssetCatalog(
            models: [:],
            materials: [
                .warmDielectric: warmDielectric
            ]
        )

        do {
            _ = try MetalResourceStore(
                device: device,
                renderAssetCatalog: incompleteCatalog,
                frameCount: MetalResourceStore.defaultFrameCount
            )
            Issue.record("Expected incomplete authored material content to fail")
        } catch let error as RenderAssetCatalogError {
            #expect(
                error == .missingMaterialDescriptions(
                    MaterialID.allCases.filter { $0 != .warmDielectric }
                )
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func residencySetsSeparateStaticAndPerFrameAllocations() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let store = try MetalResourceStore(
            device: device,
            renderAssetCatalog: BasicGameContent().renderAssetCatalog,
            frameCount: 2
        )
        let models = try MeshID.allCases.map {
            try #require(store.model(for: $0))
        }
        let textures = try TextureID.allCases.map {
            try #require(store.texture(for: $0))
        }

        #expect(
            store.residency.staticAssets.allocationCount ==
                models.flatMap(\.allocations).count + textures.count
        )
        #expect(store.residency.frameResources.allocationCount == 8)

        for model in models {
            for allocation in model.allocations {
                #expect(
                    store.residency.staticAssets.containsAllocation(allocation)
                )
                #expect(
                    !store.residency.frameResources.containsAllocation(
                        allocation
                    )
                )
            }
        }

        for texture in textures {
            #expect(store.residency.staticAssets.containsAllocation(texture))
            #expect(!store.residency.frameResources.containsAllocation(texture))
        }

        for frame in store.frames {
            let frameAllocations: [any MTLAllocation] = [
                frame.instanceBuffer,
                frame.terrestrialPlanetInstanceBuffer,
                frame.pbrSceneParametersBuffer,
                frame.hdrPresentationParametersBuffer
            ]

            // All four mutable buffers for each slot are queue-wide frame
            // residents and remain separate from immutable asset allocations.
            // Drawable-sized HDR textures instead use their own command-local
            // residency sets and therefore do not inflate this count.
            for allocation in frameAllocations {
                #expect(
                    store.residency.frameResources.containsAllocation(
                        allocation
                    )
                )
                #expect(
                    !store.residency.staticAssets.containsAllocation(allocation)
                )
            }
        }
    }
}
