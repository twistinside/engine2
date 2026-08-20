/// Positive stellar emission facts consumed by environment and atmosphere systems.
///
/// XUV luminosity is represented as a finite fraction of bolometric luminosity
/// in the closed interval `0...1`.
struct CStellarEmission: PComponent, Sendable {
    let luminosity: StellarLuminosity
    let effectiveTemperature: ThermodynamicTemperature
    let xuvLuminosityFraction: Double

    init(
        luminosity: StellarLuminosity,
        effectiveTemperature: ThermodynamicTemperature,
        xuvLuminosityFraction: Double
    ) {
        precondition(
            luminosity.watts.isFinite && luminosity.watts > 0,
            "A stellar emitter must have positive finite luminosity."
        )
        precondition(
            effectiveTemperature.kelvin.isFinite && effectiveTemperature.kelvin > 0,
            "A stellar emitter must have positive finite effective temperature."
        )
        precondition(
            xuvLuminosityFraction.isFinite && (0...1).contains(xuvLuminosityFraction),
            "A stellar emitter's XUV luminosity fraction must be finite and in 0...1."
        )
        self.luminosity = luminosity
        self.effectiveTemperature = effectiveTemperature
        self.xuvLuminosityFraction = xuvLuminosityFraction
    }
}

extension CStellarEmission {
    private enum CodingKeys: String, CodingKey {
        case luminosity
        case effectiveTemperature
        case xuvLuminosityFraction
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let luminosity = try container.decode(StellarLuminosity.self, forKey: .luminosity)
        let effectiveTemperature = try container.decode(
            ThermodynamicTemperature.self,
            forKey: .effectiveTemperature
        )
        let xuvLuminosityFraction = try container.decode(Double.self, forKey: .xuvLuminosityFraction)
        guard luminosity.watts.isFinite, luminosity.watts > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .luminosity,
                in: container,
                debugDescription: "A stellar emitter must have positive finite luminosity."
            )
        }
        guard effectiveTemperature.kelvin.isFinite, effectiveTemperature.kelvin > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .effectiveTemperature,
                in: container,
                debugDescription: "A stellar emitter must have positive finite effective temperature."
            )
        }
        guard xuvLuminosityFraction.isFinite, (0...1).contains(xuvLuminosityFraction) else {
            throw DecodingError.dataCorruptedError(
                forKey: .xuvLuminosityFraction,
                in: container,
                debugDescription: "A stellar emitter's XUV luminosity fraction must be finite and in 0...1."
            )
        }
        self.init(
            luminosity: luminosity,
            effectiveTemperature: effectiveTemperature,
            xuvLuminosityFraction: xuvLuminosityFraction
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(luminosity, forKey: .luminosity)
        try container.encode(effectiveTemperature, forKey: .effectiveTemperature)
        try container.encode(xuvLuminosityFraction, forKey: .xuvLuminosityFraction)
    }
}
