import Foundation

/// Formats celestial-dynamics facts for the explorer without changing their source values.
nonisolated struct GravitySystemPresentation: Sendable {
    func modelVersion(_ version: CelestialDynamicsModelVersion) -> String {
        switch version {
        case .planarKeplerV1: "Planar Kepler V1"
        }
    }

    func epoch(_ epoch: CelestialEpoch) -> String {
        elapsedTime(seconds: epoch.secondsSinceReferenceEpoch)
    }

    func elapsedTime(seconds: Double) -> String {
        let day = 86_400.0
        let year = AstronomicalDuration.year.seconds
        if seconds >= year {
            return "\(number(seconds / year, fractionDigits: 2)) yr"
        }
        if seconds >= day {
            return "\(number(seconds / day, fractionDigits: 2)) d"
        }
        if seconds >= 3_600 {
            return "\(number(seconds / 3_600, fractionDigits: 2)) h"
        }
        return "\(number(seconds, fractionDigits: 0)) s"
    }

    func distance(_ distance: AstronomicalDistance) -> String {
        if distance.astronomicalUnits >= 0.01 {
            return "\(number(distance.astronomicalUnits, fractionDigits: 3)) AU"
        }
        return "\(number(distance.meters / 1_000, fractionDigits: 0)) km"
    }

    func deltaV(metersPerSecond: Double) -> String {
        if metersPerSecond >= 1_000 {
            return "\(number(metersPerSecond / 1_000, fractionDigits: 2)) km/s"
        }
        return "\(number(metersPerSecond, fractionDigits: 0)) m/s"
    }

    func acceleration(metersPerSecondSquared: Double) -> String {
        if metersPerSecondSquared < 0.001 {
            return String(
                format: "%.3e m/s²",
                locale: Locale(identifier: "en_US_POSIX"),
                metersPerSecondSquared
            )
        }
        return "\(number(metersPerSecondSquared, fractionDigits: 4)) m/s²"
    }

    func angle(radians: Double) -> String {
        "\(number(radians * 180 / Double.pi, fractionDigits: 1))°"
    }

    private func number(_ value: Double, fractionDigits: Int) -> String {
        let format = "%.\(fractionDigits)f"
        return String(format: format, locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
