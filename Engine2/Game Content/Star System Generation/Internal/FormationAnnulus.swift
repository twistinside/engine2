import Foundation

/// Mutable conserved disk cell used only during one generation call.
nonisolated struct FormationAnnulus: Sendable {
    let innerRadiusAU: Double
    let outerRadiusAU: Double
    let initialGasMassEarth: Double
    var remainingGasMassEarth: Double
    var solidComposition: CelestialMassComposition

    var centerRadiusAU: Double {
        sqrt(innerRadiusAU * outerRadiusAU)
    }

    var widthAU: Double {
        outerRadiusAU - innerRadiusAU
    }

    var remainingSolidMassEarth: Double {
        solidComposition.solidMass.earthMasses
    }
}
