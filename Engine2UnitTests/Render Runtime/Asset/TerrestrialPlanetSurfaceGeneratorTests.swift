import simd
import Testing
@testable import Engine2

struct TerrestrialPlanetSurfaceGeneratorTests {
    private let width = 128
    private let height = 64

    @Test func normalReliefValidationBoundsTheFiniteGenerationDomain() {
        #expect(TerrestrialPlanetSurfaceRecipe.acceptsNormalRelief(0))
        #expect(
            TerrestrialPlanetSurfaceRecipe.acceptsNormalRelief(
                TerrestrialPlanetSurfaceRecipe.maximumNormalRelief
            )
        )
        #expect(!TerrestrialPlanetSurfaceRecipe.acceptsNormalRelief(-0.001))
        #expect(
            !TerrestrialPlanetSurfaceRecipe.acceptsNormalRelief(
                TerrestrialPlanetSurfaceRecipe.maximumNormalRelief.nextUp
            )
        )
        #expect(!TerrestrialPlanetSurfaceRecipe.acceptsNormalRelief(.infinity))
        #expect(!TerrestrialPlanetSurfaceRecipe.acceptsNormalRelief(.nan))
    }

    @Test func recipeIdentityControlsDeterministicGeneration() {
        let generator = TerrestrialPlanetSurfaceGenerator(
            width: width,
            height: height
        )
        let equivalentRecipe = TerrestrialPlanetSurfaceRecipe(
            seed: TerrestrialPlanetSurfaceRecipe.blueMarble.seed,
            normalRelief: TerrestrialPlanetSurfaceRecipe.blueMarble.normalRelief
        )
        let differentRecipe = TerrestrialPlanetSurfaceRecipe(
            seed: TerrestrialPlanetSurfaceRecipe.blueMarble.seed &+ 1,
            normalRelief: TerrestrialPlanetSurfaceRecipe.blueMarble.normalRelief
        )
        let first = generator.generate(.blueMarble)
        let second = generator.generate(equivalentRecipe)
        let different = generator.generate(differentRecipe)

        #expect(equivalentRecipe == .blueMarble)
        #expect(differentRecipe != .blueMarble)
        #expect(first == second)
        #expect(first != different)
    }

    @Test func generatedMapsContainOneCompleteRGBA8GridPerRole() {
        #expect(TerrestrialPlanetSurfaceGenerator.productionWidth == 1_024)
        #expect(TerrestrialPlanetSurfaceGenerator.productionHeight == 512)

        let maps = TerrestrialPlanetSurfaceGenerator(
            width: width,
            height: height
        ).generate(.blueMarble)
        let expectedByteCount = width
            * height
            * TerrestrialPlanetSurfaceMaps.channelCount

        #expect(maps.width == width)
        #expect(maps.height == height)
        #expect(maps.normalRGBA8.count == expectedByteCount)
        #expect(maps.surfaceRGBA8.count == expectedByteCount)
        #expect(maps.controlRGBA8.count == expectedByteCount)
        #expect(maps.cloudRGBA8.count == expectedByteCount)

        for offset in stride(from: 0, to: expectedByteCount, by: 4) {
            #expect(maps.normalRGBA8[offset + 3] == 255)
            #expect(
                maps.surfaceRGBA8[offset + 3] == 0
                    || maps.surfaceRGBA8[offset + 3] == 255
            )
            #expect(maps.cloudRGBA8[offset] == maps.cloudRGBA8[offset + 3])
        }
    }

    @Test func generatedNormalsRemainValidAcrossTheSeamAndPoles() {
        let maps = TerrestrialPlanetSurfaceGenerator(
            width: width,
            height: height
        ).generate(.blueMarble)
        var adjacentDifference: Float = 0
        var adjacentPairCount = 0
        var seamDifference: Float = 0

        for y in 0..<height {
            for x in 0..<width {
                let normal = decodedNormal(
                    maps.normalRGBA8,
                    x: x,
                    y: y
                )
                #expect((0.98...1.02).contains(simd_length(normal)))
                #expect(normal.z > 0)

                guard x + 1 < width else {
                    continue
                }
                adjacentDifference += simd_distance(
                    normal,
                    decodedNormal(
                        maps.normalRGBA8,
                        x: x + 1,
                        y: y
                    )
                )
                adjacentPairCount += 1
            }

            seamDifference += simd_distance(
                decodedNormal(maps.normalRGBA8, x: 0, y: y),
                decodedNormal(maps.normalRGBA8, x: width - 1, y: y)
            )
        }

        let meanAdjacentDifference = adjacentDifference
            / Float(adjacentPairCount)
        let meanSeamDifference = seamDifference / Float(height)
        #expect(meanSeamDifference <= meanAdjacentDifference * 4 + 0.1)

        for poleRow in [0, height - 1] {
            let meanRadialComponent = (0..<width).reduce(Float.zero) { partialResult, x in
                partialResult + decodedNormal(
                    maps.normalRGBA8,
                    x: x,
                    y: poleRow
                ).z
            } / Float(width)
            #expect(meanRadialComponent > 0.7)
        }
    }

    @Test func generatedMapsContainBlueMarbleSurfaceRegions() {
        let maps = TerrestrialPlanetSurfaceGenerator(
            width: width,
            height: height
        ).generate(.blueMarble)
        let pacificSurface = pixel(
            maps.surfaceRGBA8,
            longitudeDegrees: -150,
            latitudeDegrees: 0
        )
        let centralAfricaSurface = pixel(
            maps.surfaceRGBA8,
            longitudeDegrees: 20,
            latitudeDegrees: 0
        )
        let antarcticSurface = pixel(
            maps.surfaceRGBA8,
            longitudeDegrees: 20,
            latitudeDegrees: -80
        )
        let antarcticControl = pixel(
            maps.controlRGBA8,
            longitudeDegrees: 20,
            latitudeDegrees: -80
        )

        #expect(pacificSurface.w == 0)
        #expect(
            pacificSurface.z > pacificSurface.x
                && pacificSurface.z > pacificSurface.y
        )
        #expect(centralAfricaSurface.w == 255)
        #expect(antarcticSurface.w == 255)
        #expect(antarcticControl.z > 128)

        let pixelCount = width * height
        var landCount = 0
        var blueOceanCount = 0
        var vegetationCount = 0
        var iceCount = 0
        var cloudyCount = 0
        var clearCount = 0
        for offset in stride(from: 0, to: maps.surfaceRGBA8.count, by: 4) {
            let isLand = maps.surfaceRGBA8[offset + 3] == 255
            if isLand {
                landCount += 1
            } else if maps.surfaceRGBA8[offset + 2] > maps.surfaceRGBA8[offset]
                && maps.surfaceRGBA8[offset + 2] > maps.surfaceRGBA8[offset + 1]
            {
                blueOceanCount += 1
            }
            if maps.controlRGBA8[offset + 1] > 64 {
                vegetationCount += 1
            }
            if maps.controlRGBA8[offset + 2] > 128 {
                iceCount += 1
            }
            if maps.cloudRGBA8[offset] > 51 {
                cloudyCount += 1
            }
            if maps.cloudRGBA8[offset] < 26 {
                clearCount += 1
            }
        }

        #expect((pixelCount / 10...pixelCount * 3 / 4).contains(landCount))
        #expect(blueOceanCount > pixelCount / 5)
        #expect(vegetationCount > pixelCount / 100)
        #expect(iceCount > pixelCount / 100)
        #expect(cloudyCount > pixelCount / 10)
        #expect(clearCount > pixelCount / 10)
    }

    private func decodedNormal(
        _ bytes: [UInt8],
        x: Int,
        y: Int
    ) -> SIMD3<Float> {
        let offset = (y * width + x) * 4
        return SIMD3<Float>(
            decodedNormalChannel(bytes[offset]),
            decodedNormalChannel(bytes[offset + 1]),
            decodedNormalChannel(bytes[offset + 2])
        )
    }

    private func decodedNormalChannel(_ sample: UInt8) -> Float {
        Float(sample) / 255 * 2 - 1
    }

    private func pixel(
        _ bytes: [UInt8],
        longitudeDegrees: Float,
        latitudeDegrees: Float
    ) -> SIMD4<UInt8> {
        let x = min(
            max(Int((longitudeDegrees / 360 + 0.5) * Float(width)), 0),
            width - 1
        )
        let y = min(
            max(Int((0.5 - latitudeDegrees / 180) * Float(height)), 0),
            height - 1
        )
        let offset = (y * width + x) * 4
        return SIMD4<UInt8>(
            bytes[offset],
            bytes[offset + 1],
            bytes[offset + 2],
            bytes[offset + 3]
        )
    }
}
