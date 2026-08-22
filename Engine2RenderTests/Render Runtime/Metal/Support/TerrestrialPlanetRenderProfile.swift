import Foundation
@testable import Engine2

/// Semantic image-space measurements for the Blue Marble-inspired proof.
///
/// The profile intentionally measures broad composition and color populations
/// rather than comparing against NASA pixels or a GPU-specific golden image.
struct TerrestrialPlanetRenderProfile {
    let diskDiameterFraction: Double
    let diskCenterXFraction: Double
    let diskCenterYFraction: Double
    let blueDominantFraction: Double
    let warmLandFraction: Double
    let greenVegetationFraction: Double
    let brightNeutralFraction: Double
    let luminanceP10: Int
    let luminanceP90: Int
    let westMidDiskBlueFraction: Double
    let eastMidDiskBlueFraction: Double
    let centralAfricaLandFraction: Double
    let southernBrightNeutralFraction: Double
    let northernBrightNeutralFraction: Double

    init?(pixels: [UInt8], size: RenderPixelSize) {
        guard
            pixels.count == size.bgra8ByteCount,
            let geometry = Self.diskGeometry(in: pixels, size: size)
        else {
            return nil
        }
        let samples = Self.innerDiskSamples(
            in: pixels,
            size: size,
            centerX: geometry.centerX,
            centerY: geometry.centerY,
            radius: geometry.radius
        )
        guard
            !samples.isEmpty,
            let regional = Self.regionalMeasurements(in: samples)
        else {
            return nil
        }
        let global = Self.globalMeasurements(in: samples)

        self.diskDiameterFraction = geometry.radius * 2
            / Double(size.width)
        self.diskCenterXFraction = geometry.centerX / Double(size.width)
        self.diskCenterYFraction = geometry.centerY / Double(size.height)
        self.blueDominantFraction = global.blueDominantFraction
        self.warmLandFraction = global.warmLandFraction
        self.greenVegetationFraction = global.greenVegetationFraction
        self.brightNeutralFraction = global.brightNeutralFraction
        self.luminanceP10 = global.luminanceP10
        self.luminanceP90 = global.luminanceP90
        self.westMidDiskBlueFraction = regional.westMidDiskBlueFraction
        self.eastMidDiskBlueFraction = regional.eastMidDiskBlueFraction
        self.centralAfricaLandFraction = regional.centralAfricaLandFraction
        self.southernBrightNeutralFraction = regional
            .southernBrightNeutralFraction
        self.northernBrightNeutralFraction = regional
            .northernBrightNeutralFraction
    }

    /// Finds the visible globe against the proof scene's black background.
    private static func diskGeometry(
        in pixels: [UInt8],
        size: RenderPixelSize
    ) -> (centerX: Double, centerY: Double, radius: Double)? {
        var minimumX = size.width
        var maximumX = 0
        var minimumY = size.height
        var maximumY = 0

        for y in 0..<size.height {
            for x in 0..<size.width {
                let offset = (y * size.width + x) * 4
                let blue = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let red = Int(pixels[offset + 2])
                guard max(red, max(green, blue)) > 12 else {
                    continue
                }
                minimumX = min(minimumX, x)
                maximumX = max(maximumX, x)
                minimumY = min(minimumY, y)
                maximumY = max(maximumY, y)
            }
        }

        guard minimumX <= maximumX, minimumY <= maximumY else {
            return nil
        }
        let diskWidth = maximumX - minimumX + 1
        let diskHeight = maximumY - minimumY + 1
        return (
            centerX: Double(minimumX + maximumX) / 2,
            centerY: Double(minimumY + maximumY) / 2,
            radius: Double(min(diskWidth, diskHeight)) / 2
        )
    }

    /// Extracts a stable interior that excludes the atmosphere and edge AA.
    private static func innerDiskSamples(
        in pixels: [UInt8],
        size: RenderPixelSize,
        centerX: Double,
        centerY: Double,
        radius: Double
    ) -> [(red: Int, green: Int, blue: Int, x: Double, y: Double)] {
        let innerRadius = radius * 0.82
        var samples: [(
            red: Int,
            green: Int,
            blue: Int,
            x: Double,
            y: Double
        )] = []
        samples.reserveCapacity(Int(.pi * innerRadius * innerRadius))

        for y in 0..<size.height {
            for x in 0..<size.width {
                let deltaX = Double(x) - centerX
                let deltaY = Double(y) - centerY
                guard hypot(deltaX, deltaY) <= innerRadius else {
                    continue
                }

                let offset = (y * size.width + x) * 4
                samples.append(
                    (
                        red: Int(pixels[offset + 2]),
                        green: Int(pixels[offset + 1]),
                        blue: Int(pixels[offset]),
                        x: deltaX / radius,
                        y: deltaY / radius
                    )
                )
            }
        }
        return samples
    }

    /// Measures global color hierarchy and display-space contrast.
    private static func globalMeasurements(
        in samples: [(red: Int, green: Int, blue: Int, x: Double, y: Double)]
    ) -> (
        blueDominantFraction: Double,
        warmLandFraction: Double,
        greenVegetationFraction: Double,
        brightNeutralFraction: Double,
        luminanceP10: Int,
        luminanceP90: Int
    ) {
        var blueDominantCount = 0
        var warmLandCount = 0
        var greenVegetationCount = 0
        var brightNeutralCount = 0
        var luminances: [Int] = []
        luminances.reserveCapacity(samples.count)

        for sample in samples {
            let lowestChannel = min(
                sample.red,
                min(sample.green, sample.blue)
            )
            let highestChannel = max(
                sample.red,
                max(sample.green, sample.blue)
            )
            blueDominantCount += sample.blue > sample.green + 8
                && sample.green > sample.red + 3 ? 1 : 0
            warmLandCount += sample.red > sample.green + 8
                && sample.green > sample.blue + 3 ? 1 : 0
            greenVegetationCount += sample.green > sample.red + 8
                && sample.green > sample.blue + 3 ? 1 : 0
            brightNeutralCount += lowestChannel > 180
                && highestChannel - lowestChannel < 55 ? 1 : 0
            luminances.append(
                (54 * sample.red + 183 * sample.green + 19 * sample.blue)
                    / 256
            )
        }

        luminances.sort()
        let sampleCount = Double(samples.count)
        return (
            blueDominantFraction: Double(blueDominantCount) / sampleCount,
            warmLandFraction: Double(warmLandCount) / sampleCount,
            greenVegetationFraction: Double(greenVegetationCount) / sampleCount,
            brightNeutralFraction: Double(brightNeutralCount) / sampleCount,
            luminanceP10: luminances[luminances.count / 10],
            luminanceP90: luminances[luminances.count * 9 / 10]
        )
    }

    /// Measures the target's oceans, Africa, and southern bright weather.
    private static func regionalMeasurements(
        in samples: [(red: Int, green: Int, blue: Int, x: Double, y: Double)]
    ) -> (
        westMidDiskBlueFraction: Double,
        eastMidDiskBlueFraction: Double,
        centralAfricaLandFraction: Double,
        southernBrightNeutralFraction: Double,
        northernBrightNeutralFraction: Double
    )? {
        var westMidDiskBlueCount = 0
        var westMidDiskPixelCount = 0
        var eastMidDiskBlueCount = 0
        var eastMidDiskPixelCount = 0
        var centralAfricaLandCount = 0
        var centralAfricaPixelCount = 0
        var southernBrightNeutralCount = 0
        var southernPixelCount = 0
        var northernBrightNeutralCount = 0
        var northernPixelCount = 0

        for sample in samples {
            let lowestChannel = min(
                sample.red,
                min(sample.green, sample.blue)
            )
            let highestChannel = max(
                sample.red,
                max(sample.green, sample.blue)
            )
            let isBlueDominant = sample.blue > sample.green + 8
                && sample.green > sample.red + 3
            let isLand = (
                sample.red > sample.green + 8
                    && sample.green > sample.blue + 3
            ) || (
                sample.green > sample.red + 8
                    && sample.green > sample.blue + 3
            )
            let isBrightNeutral = lowestChannel > 180
                && highestChannel - lowestChannel < 55

            if sample.x > -0.75, sample.x < -0.15, abs(sample.y) < 0.50 {
                westMidDiskPixelCount += 1
                westMidDiskBlueCount += isBlueDominant ? 1 : 0
            }
            if sample.x > 0.15, sample.x < 0.75, abs(sample.y) < 0.50 {
                eastMidDiskPixelCount += 1
                eastMidDiskBlueCount += isBlueDominant ? 1 : 0
            }
            if abs(sample.x) < 0.25, sample.y > -0.55, sample.y < 0.20 {
                centralAfricaPixelCount += 1
                centralAfricaLandCount += isLand ? 1 : 0
            }
            if sample.y > 0.15 {
                southernPixelCount += 1
                southernBrightNeutralCount += isBrightNeutral ? 1 : 0
            }
            if sample.y < -0.15 {
                northernPixelCount += 1
                northernBrightNeutralCount += isBrightNeutral ? 1 : 0
            }
        }

        guard
            westMidDiskPixelCount > 0,
            eastMidDiskPixelCount > 0,
            centralAfricaPixelCount > 0,
            southernPixelCount > 0,
            northernPixelCount > 0
        else {
            return nil
        }
        return (
            westMidDiskBlueFraction: Double(westMidDiskBlueCount)
                / Double(westMidDiskPixelCount),
            eastMidDiskBlueFraction: Double(eastMidDiskBlueCount)
                / Double(eastMidDiskPixelCount),
            centralAfricaLandFraction: Double(centralAfricaLandCount)
                / Double(centralAfricaPixelCount),
            southernBrightNeutralFraction: Double(southernBrightNeutralCount)
                / Double(southernPixelCount),
            northernBrightNeutralFraction: Double(northernBrightNeutralCount)
                / Double(northernPixelCount)
        )
    }
}
