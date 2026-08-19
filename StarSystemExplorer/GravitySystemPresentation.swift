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

    func gravityFieldFailureMessage(_ error: PlanarGravityFieldError) -> String {
        switch error {
        case .snapshotSystemMismatch:
            "Gravity states came from another generated system."
        case .contactWithStar:
            "The selected position overlaps the generated star."
        case .contactWithBody:
            "The selected position overlaps another generated body."
        case .nonfiniteAcceleration:
            "The combined gravity result is not finite."
        }
    }

    func gravityProjectionFailureMessage(_ error: GravitySystemGenerationError) -> String {
        switch error {
        case .unsupportedDynamicsModel(let version):
            "The explorer does not support \(modelVersion(version))."
        case .invalidSourceSystem:
            "The generated star system failed validation."
        case .invalidStar:
            "The generated star cannot source a finite gravity field."
        case .bodiesNotOrdered:
            "The projected bodies are not in their required stable order."
        case .duplicateBodyID:
            "The gravity projection contains a duplicate body identity."
        case .invalidBody:
            "A generated body cannot form a valid gravity rail."
        case .missingParent:
            "A generated moon refers to a parent that is not present."
        case .periapsisIntersectsPrimary:
            "A generated rail intersects its primary body."
        case .inconsistentPhase:
            "A generated body has inconsistent orbital phase data."
        case .inconsistentGravitationalParameter:
            "A generated body has an inconsistent gravitational parameter."
        }
    }

    func transferFailureMessage(_ error: HohmannTransferError) -> String {
        switch error {
        case .unknownBody:
            "A selected body is not part of this gravity system."
        case .identicalBodies:
            "Choose two different planets."
        case .requiresPlanet:
            "Circular-reference planning currently supports planets only."
        case .departureBeforeReferenceEpoch:
            "The requested departure precedes the gravity-system reference epoch."
        case .coincidentReferenceOrbits:
            "The selected planets have indistinguishable circular reference orbits."
        case .unrepresentableTransfer:
            "The selected circular-reference transfer cannot be represented."
        }
    }

    private func number(_ value: Double, fractionDigits: Int) -> String {
        let format = "%.\(fractionDigits)f"
        return String(format: format, locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
