import Metal
import simd
import Testing
@testable import Engine2

@MainActor
struct PBRDirectLightingTests {
    private let baseColor = SIMD3<Float>(0.5, 0.25, 0.125)

    @Test func proofCompilesEveryDiagnosticIntoALinearHalfFloatPipeline() throws {
        let renderer = try MetalPBRProofRenderer()

        #expect(MetalPBRProofRenderer.colorPixelFormat == .rgba16Float)
        for output in PBRProofOutput.allCases {
            let image = try renderer.render(output)
            let foreground = image.filter { $0.w > 0.5 }

            #expect(!foreground.isEmpty)
            #expect(
                foreground.allSatisfy { pixel in
                    pixel.x.isFinite
                        && pixel.y.isFinite
                        && pixel.z.isFinite
                        && pixel.x >= 0
                        && pixel.y >= 0
                        && pixel.z >= 0
                }
            )
        }
    }

    @Test func diagnosticsExposeTheEvaluatorInputsAtSphereCenter() throws {
        let renderer = try MetalPBRProofRenderer()
        let parameters = PBRProofParameters(
            baseColor: SIMD3<Float>(0.2, 0.4, 0.8),
            metallic: 0.75,
            perceptualRoughness: 0.3,
            directionToLightWorld: SIMD3<Float>(0, 3, 4),
            lightColor: SIMD3<Float>(repeating: 1),
            lightIntensity: 1,
            directionToCameraView: SIMD3<Float>(0, 0, 1)
        )

        // At the center of the analytic sphere, N is view-space +Z. The
        // normalized 3-4-5 light direction therefore gives N dot L = 0.8.
        // Exact diagnostics catch swapped entry points, accidental transfer
        // encoding, or a proof shader that bypasses the shared evaluator.
        expectStoredRGB(
            center(try renderer.render(.normal, parameters: parameters)),
            approximately: SIMD3<Float>(0.5, 0.5, 1)
        )
        expectStoredRGB(
            center(try renderer.render(.baseColor, parameters: parameters)),
            approximately: SIMD3<Float>(0.2, 0.4, 0.8)
        )
        expectStoredRGB(
            center(try renderer.render(.metallic, parameters: parameters)),
            approximately: SIMD3<Float>(repeating: 0.75)
        )
        expectStoredRGB(
            center(try renderer.render(.roughness, parameters: parameters)),
            approximately: SIMD3<Float>(repeating: 0.3)
        )
        expectStoredRGB(
            center(try renderer.render(.nDotL, parameters: parameters)),
            approximately: SIMD3<Float>(repeating: 0.8)
        )
    }

    @Test func normalIncidenceMatchesIndependentDielectricAndMetalReferences() throws {
        let renderer = try MetalPBRProofRenderer()
        let dielectric = proofParameters(metallic: 0, roughness: 0.5)
        let metal = proofParameters(metallic: 1, roughness: 0.5)

        let dielectricShaded = center(
            try renderer.render(.shaded, parameters: dielectric)
        )
        let dielectricDiffuse = center(
            try renderer.render(.diffuse, parameters: dielectric)
        )
        let dielectricSpecular = center(
            try renderer.render(.specular, parameters: dielectric)
        )
        let metalShaded = center(
            try renderer.render(.shaded, parameters: metal)
        )
        let metalDiffuse = center(
            try renderer.render(.diffuse, parameters: metal)
        )

        expectStoredRGB(
            dielectricDiffuse,
            approximately: SIMD3<Float>(
                0.15278875,
                0.07639437,
                0.03819719
            )
        )
        expectStoredRGB(
            dielectricSpecular,
            approximately: SIMD3<Float>(repeating: 0.05092958)
        )
        expectStoredRGB(
            dielectricShaded,
            approximately: SIMD3<Float>(
                0.20371833,
                0.12732395,
                0.08912677
            )
        )
        expectStoredRGB(
            metalShaded,
            approximately: SIMD3<Float>(
                0.63661977,
                0.31830989,
                0.15915494
            )
        )
        expectStoredRGB(metalDiffuse, approximately: .zero)
    }

    @Test func asymmetricGeometryMatchesIndependentBRDFReferences() throws {
        let renderer = try MetalPBRProofRenderer()
        let parameters = PBRProofParameters(
            baseColor: baseColor,
            metallic: 0.35,
            perceptualRoughness: 0.6,
            directionToLightWorld: SIMD3<Float>(-0.8, 0, 0.6),
            lightColor: SIMD3<Float>(repeating: 1),
            lightIntensity: 1,
            directionToCameraView: SIMD3<Float>(sqrt(0.99), 0, 0.1)
        )

        // Here N dot V differs from N dot L, and V dot H differs from both.
        // These independently calculated half-float references fail if Schlick
        // uses N dot V or N dot L, or if either correlated-Smith leg is
        // duplicated.
        expectStoredRGB(
            center(try renderer.render(.diffuse, parameters: parameters)),
            approximately: SIMD3<Float>(
                0.044403076171875,
                0.024627685546875,
                0.0129241943359375
            )
        )
        expectStoredRGB(
            center(try renderer.render(.specular, parameters: parameters)),
            approximately: SIMD3<Float>(
                0.328857421875,
                0.23828125,
                0.193115234375
            )
        )
        expectStoredRGB(
            center(try renderer.render(.shaded, parameters: parameters)),
            approximately: SIMD3<Float>(
                0.373291015625,
                0.262939453125,
                0.2059326171875
            )
        )
    }

    @Test func lightBehindTheSurfaceContributesNothing() throws {
        let renderer = try MetalPBRProofRenderer()
        let parameters = PBRProofParameters(
            baseColor: baseColor,
            metallic: 0.35,
            perceptualRoughness: 0.6,
            directionToLightWorld: SIMD3<Float>(0.8, 0, -0.6),
            lightColor: SIMD3<Float>(repeating: 1),
            lightIntensity: 1,
            directionToCameraView: SIMD3<Float>(0, 0, 1)
        )

        // Center-sphere N and V are +Z, while L is below the surface. Every
        // direct-light output must remain exactly zero; using abs(N dot L) or
        // omitting the one-sided rejection would make this case visibly lit.
        for output in [
            PBRProofOutput.nDotL,
            .diffuse,
            .specular,
            .shaded
        ] {
            expectStoredRGB(
                center(try renderer.render(output, parameters: parameters)),
                approximately: .zero
            )
        }
    }

    @Test func cameraBehindTheSurfaceContributesNothing() throws {
        let renderer = try MetalPBRProofRenderer()
        let parameters = PBRProofParameters(
            baseColor: baseColor,
            metallic: 0.35,
            perceptualRoughness: 0.6,
            directionToLightWorld: SIMD3<Float>(0, 0, 1),
            lightColor: SIMD3<Float>(repeating: 1),
            lightIntensity: 1,
            directionToCameraView: SIMD3<Float>(0.8, 0, -0.6)
        )

        // Center-sphere N and L are +Z, while V is below the surface. This is
        // intentionally separate from the light-backface case: abs(N dot V)
        // or an omitted camera-side rejection would otherwise survive every
        // exact BRDF reference above.
        for output in [
            PBRProofOutput.diffuse,
            .specular,
            .shaded
        ] {
            expectStoredRGB(
                center(try renderer.render(output, parameters: parameters)),
                approximately: .zero
            )
        }
    }

    @Test func proofTargetPreservesLinearFactorsAndHDRValues() throws {
        let renderer = try MetalPBRProofRenderer()
        let linearBaseColor = center(
            try renderer.render(
                .baseColor,
                parameters: proofParameters(metallic: 0, roughness: 0.5)
            )
        )
        let hdrParameters = PBRProofParameters(
            baseColor: baseColor,
            metallic: 0,
            perceptualRoughness: 0.5,
            directionToLightWorld: SIMD3<Float>(0, 0, 1),
            lightColor: SIMD3<Float>(8, 4, 2),
            lightIntensity: 1,
            directionToCameraView: SIMD3<Float>(0, 0, 1)
        )
        let hdrShaded = center(
            try renderer.render(.shaded, parameters: hdrParameters)
        )

        expectStoredRGB(linearBaseColor, approximately: baseColor)
        expectStoredRGB(
            hdrShaded,
            approximately: SIMD3<Float>(
                1.6297466,
                0.5092958,
                0.17825353
            )
        )
        #expect(hdrShaded.x > 1)
    }

    @Test func increasingRoughnessLowersThePeakAndBroadensTheSpecularLobe() throws {
        let renderer = try MetalPBRProofRenderer()
        let smooth = try renderer.render(
            .specular,
            parameters: proofParameters(metallic: 1, roughness: 0.2)
        )
        let rough = try renderer.render(
            .specular,
            parameters: proofParameters(metallic: 1, roughness: 0.8)
        )

        #expect(luminance(center(smooth)) > luminance(center(rough)))
        #expect(radialMoment(of: rough) > radialMoment(of: smooth))
    }

    @Test func publishedSceneRoughnessProgressionsDimAndBroadenSpecularLobes() throws {
        let scene = PublishedMaterialValidationScene()
        let descriptions = try scene.materialDescriptions()
        let publishedMaterials = zip(scene.materialIDs, descriptions).map {
            (id: $0.0, description: $0.1)
        }
        let renderer = try MetalPBRProofRenderer()

        #expect(publishedMaterials.count == 6)

        // The builder publishes three dielectric and three metallic spheres.
        // Within each row, base color and metallic stay fixed while authored
        // roughness increases. Deriving the proof inputs from the catalog keeps
        // this lobe check attached to the actual M5 content rather than literals.
        for metallic in [Float(0), Float(1)] {
            let progression = publishedMaterials
                .filter { $0.description.metallic == metallic }
                .sorted {
                    $0.description.perceptualRoughness
                        < $1.description.perceptualRoughness
                }

            #expect(progression.count == 3)
            guard let first = progression.first else {
                continue
            }
            #expect(
                progression.allSatisfy {
                    $0.description.baseColor == first.description.baseColor
                }
            )

            let specularImages = try progression.map { material in
                try renderer.render(
                    .specular,
                    parameters: proofParameters(
                        material: material.description
                    )
                )
            }

            for roughnessIndex in 1..<specularImages.count {
                let smoother = specularImages[roughnessIndex - 1]
                let rougher = specularImages[roughnessIndex]
                #expect(luminance(center(smoother)) > luminance(center(rougher)))
                #expect(radialMoment(of: smoother) < radialMoment(of: rougher))
            }
        }
    }

    @Test func shadedOutputIsTheStoredSumOfDiffuseAndSpecularContributions() throws {
        let renderer = try MetalPBRProofRenderer()
        let parameters = proofParameters(metallic: 0.35, roughness: 0.6)
        let shaded = try renderer.render(.shaded, parameters: parameters)
        let diffuse = try renderer.render(.diffuse, parameters: parameters)
        let specular = try renderer.render(.specular, parameters: parameters)

        for pixelIndex in shaded.indices where shaded[pixelIndex].w > 0.5 {
            let expected = diffuse[pixelIndex] + specular[pixelIndex]
            expectRGB(
                shaded[pixelIndex],
                approximately: SIMD3<Float>(
                    expected.x,
                    expected.y,
                    expected.z
                ),
                tolerance: 0.004
            )
        }
    }

    @Test func grazingAndRoughnessEndpointInputsRemainFinite() throws {
        let renderer = try MetalPBRProofRenderer()
        let grazingCosine: Float = 0.01
        let tangent = sqrt(1 - grazingCosine * grazingCosine)
        let grazingParameters = PBRProofParameters(
            baseColor: baseColor,
            metallic: 0,
            perceptualRoughness: 0.5,
            directionToLightWorld: SIMD3<Float>(
                -tangent,
                0,
                grazingCosine
            ),
            lightColor: SIMD3<Float>(repeating: 1),
            lightIntensity: 1,
            directionToCameraView: SIMD3<Float>(
                tangent,
                0,
                grazingCosine
            )
        )
        let grazingShaded = try renderer.render(
            .shaded,
            parameters: grazingParameters
        )
        let centerPixel = center(grazingShaded)

        #expect(
            grazingShaded.allSatisfy { pixel in
                pixel.x.isFinite && pixel.y.isFinite && pixel.z.isFinite
            }
        )
        expectRGB(
            centerPixel,
            approximately: SIMD3<Float>(
                4.849776,
                4.849738,
                4.849720
            ),
            tolerance: 0.02
        )

        // Exercise the proof roughness endpoint separately under aligned
        // directions. The evaluator maps zero to its documented 0.089 floor,
        // keeping the GGX peak representable in the half-float proof target.
        let endpointParameters = proofParameters(metallic: 0, roughness: 0)
        let endpointShaded = try renderer.render(
            .shaded,
            parameters: endpointParameters
        )
        #expect(
            endpointShaded.allSatisfy { pixel in
                pixel.x.isFinite && pixel.y.isFinite && pixel.z.isFinite
            }
        )
        let endpointSpecular = center(
            try renderer.render(
                .specular,
                parameters: endpointParameters
            )
        )
        expectStoredRGB(
            endpointSpecular,
            approximately: SIMD3<Float>(repeating: 50.732948)
        )
        let effectiveRoughness = center(
            try renderer.render(
                .roughness,
                parameters: endpointParameters
            )
        )
        expectStoredRGB(
            effectiveRoughness,
            approximately: SIMD3<Float>(repeating: 0.089)
        )
    }

    private func proofParameters(
        metallic: Float,
        roughness: Float
    ) -> PBRProofParameters {
        PBRProofParameters(
            baseColor: baseColor,
            metallic: metallic,
            perceptualRoughness: roughness,
            directionToLightWorld: SIMD3<Float>(0, 0, 1),
            lightColor: SIMD3<Float>(repeating: 1),
            lightIntensity: 1,
            directionToCameraView: SIMD3<Float>(0, 0, 1)
        )
    }

    /// Converts one Render-owned catalog description into the isolated proof's
    /// provisional binding while preserving its authored factors exactly.
    private func proofParameters(
        material: PBRMaterialDescription
    ) -> PBRProofParameters {
        PBRProofParameters(
            baseColor: material.baseColor,
            metallic: material.metallic,
            perceptualRoughness: material.perceptualRoughness,
            directionToLightWorld: SIMD3<Float>(0, 0, 1),
            lightColor: SIMD3<Float>(repeating: 1),
            lightIntensity: 1,
            directionToCameraView: SIMD3<Float>(0, 0, 1)
        )
    }
}

private func center(_ image: [SIMD4<Float>]) -> SIMD4<Float> {
    let centerX = MetalPBRProofRenderer.width / 2
    let centerY = MetalPBRProofRenderer.height / 2
    return image[centerY * MetalPBRProofRenderer.width + centerX]
}

private func expectRGB(
    _ actual: SIMD4<Float>,
    approximately expected: SIMD3<Float>,
    tolerance: Float
) {
    #expect(abs(actual.x - expected.x) <= tolerance)
    #expect(abs(actual.y - expected.y) <= tolerance)
    #expect(abs(actual.z - expected.z) <= tolerance)
    #expect(abs(actual.w - 1) <= tolerance)
}

/// Compares values at the precision the proof target actually stores.
///
/// All BRDF outputs are nonnegative, so positive IEEE-754 half bit patterns are
/// monotonically ordered. A two-ULP allowance covers harmless instruction
/// ordering while remaining tight enough to reject materially different math.
private func expectStoredRGB(
    _ actual: SIMD4<Float>,
    approximately expected: SIMD3<Float>,
    maximumHalfULPDistance: Int = 2
) {
    let actualComponents = [actual.x, actual.y, actual.z, actual.w]
    let expectedComponents = [expected.x, expected.y, expected.z, 1]

    for componentIndex in actualComponents.indices {
        let actualHalf = Float16(actualComponents[componentIndex])
        let expectedHalf = Float16(expectedComponents[componentIndex])
        let ulpDistance = abs(
            Int(actualHalf.bitPattern) - Int(expectedHalf.bitPattern)
        )
        #expect(ulpDistance <= maximumHalfULPDistance)
    }
}

private func luminance(_ pixel: SIMD4<Float>) -> Float {
    simd_dot(
        SIMD3<Float>(pixel.x, pixel.y, pixel.z),
        SIMD3<Float>(0.2126, 0.7152, 0.0722)
    )
}

private func radialMoment(of image: [SIMD4<Float>]) -> Float {
    let centerX = Float(MetalPBRProofRenderer.width - 1) / 2
    let centerY = Float(MetalPBRProofRenderer.height - 1) / 2
    var weightedDistance: Float = 0
    var totalWeight: Float = 0

    for y in 0..<MetalPBRProofRenderer.height {
        for x in 0..<MetalPBRProofRenderer.width {
            let pixel = image[y * MetalPBRProofRenderer.width + x]
            guard pixel.w > 0.5 else {
                continue
            }

            let weight = luminance(pixel)
            let dx = (Float(x) - centerX) / centerX
            let dy = (Float(y) - centerY) / centerY
            weightedDistance += weight * (dx * dx + dy * dy)
            totalWeight += weight
        }
    }

    return weightedDistance / max(totalWeight, .leastNormalMagnitude)
}
