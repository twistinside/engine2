import Foundation

/// Projects generator facts into concise labels and units without changing the persisted domain model.
nonisolated struct StarSystemPresentation: Sendable {
    func number(_ value: Double) -> String {
        guard value.isFinite else {
            return "—"
        }
        let magnitude = abs(value)
        if magnitude == 0 {
            return "0"
        }
        if magnitude < 0.01 {
            return String(format: "%.3g", locale: Locale(identifier: "en_US_POSIX"), value)
        }
        if magnitude >= 10_000 {
            return String(format: "%.3e", locale: Locale(identifier: "en_US_POSIX"), value)
        }
        if magnitude >= 100 {
            return String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), value)
        }
        if magnitude >= 10 {
            return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
        }
        return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    func percent(_ fraction: Double) -> String {
        "\(number(fraction * 100))%"
    }

    func earthMasses(_ mass: AstronomicalMass) -> String {
        "\(number(mass.earthMasses)) M⊕"
    }

    func earthRadii(_ distance: AstronomicalDistance) -> String {
        "\(number(distance.earthRadii)) R⊕"
    }

    func astronomicalUnits(_ distance: AstronomicalDistance) -> String {
        "\(number(distance.astronomicalUnits)) AU"
    }

    func kilometers(_ distance: AstronomicalDistance) -> String {
        "\(number(distance.meters / 1_000)) km"
    }

    func kelvin(_ temperature: ThermodynamicTemperature) -> String {
        "\(number(temperature.kelvin)) K"
    }

    func bars(_ pressure: SurfacePressure?) -> String {
        guard let pressure else {
            return "Hidden by deep envelope"
        }
        return "\(number(pressure.bars)) bar"
    }

    func bodyID(_ id: GeneratedBodyID) -> String {
        "#\(id.rawValue)"
    }

    func seed(_ seed: StarSystemSeed) -> String {
        "\(seed.rawValue)  ·  0x\(String(seed.rawValue, radix: 16, uppercase: true))"
    }

    func resolvedPlanetRangeLabel(count: Int) -> String {
        count == 0 ? "No resolved planets" : "P1…P\(count)"
    }

    func label(for value: PlanetaryBulkRegime) -> String {
        switch value {
        case .metalRich: "Metal rich"
        case .rocky: "Rocky"
        case .volatileRich: "Volatile rich"
        case .hydrogenHeliumDominated: "H/He dominated"
        }
    }

    func classificationHelp(for value: PlanetaryBulkRegime) -> String {
        switch value {
        case .metalRich: "Iron is at least 38% of the body's solid mass."
        case .rocky: "Rock and metal dominate the solid mass without meeting the metal-rich threshold."
        case .volatileRich: "Water and other volatiles are at least 25% of the body's solid mass."
        case .hydrogenHeliumDominated: "Hydrogen and helium are at least half of the body's total mass."
        }
    }

    func label(for value: PlanetaryVisibleBoundary) -> String {
        switch value {
        case .exposedSolid: "Exposed solid"
        case .opaqueAtmosphere: "Opaque atmosphere"
        }
    }

    func classificationHelp(for value: PlanetaryVisibleBoundary) -> String {
        switch value {
        case .exposedSolid: "The solid surface supplies the body's visible boundary."
        case .opaqueAtmosphere: "A deep gas envelope hides the solid surface."
        }
    }

    func label(for value: PlanetaryAtmosphereRegime) -> String {
        switch value {
        case .airless: "Airless"
        case .tenuous: "Tenuous air"
        case .secondary: "Secondary air"
        case .deepEnvelope: "Deep envelope"
        }
    }

    func classificationHelp(for value: PlanetaryAtmosphereRegime) -> String {
        switch value {
        case .airless: "No resolved atmosphere remains."
        case .tenuous: "A positive atmosphere remains below 0.05 bar."
        case .secondary: "The exposed atmosphere has at least 0.05 bar of surface pressure."
        case .deepEnvelope: "An opaque gas envelope prevents a surface-pressure estimate."
        }
    }

    func label(for value: PlanetaryThermalRegime) -> String {
        switch value {
        case .frozen: "Frozen"
        case .temperate: "Temperate"
        case .hot: "Hot"
        case .molten: "Molten"
        }
    }

    func classificationHelp(for value: PlanetaryThermalRegime) -> String {
        switch value {
        case .frozen: "The visible-boundary temperature is below 240 K."
        case .temperate: "The visible-boundary temperature is from 240 K through 350 K."
        case .hot: "The visible-boundary temperature is above 350 K and below 1,200 K."
        case .molten: "The visible-boundary temperature is at least 1,200 K."
        }
    }

    func label(for value: PlanetaryWaterRegime) -> String {
        switch value {
        case .dry: "Dry"
        case .iceCovered: "Ice covered"
        case .partialLiquid: "Partial liquid"
        case .globalOcean: "Global ocean"
        case .steam: "Steam"
        case .inaccessible: "Inaccessible water"
        }
    }

    func classificationHelp(for value: PlanetaryWaterRegime) -> String {
        switch value {
        case .dry: "The accessible water inventory is negligible or absent."
        case .iceCovered: "Accessible water is surface ice, with no liquid-water coverage."
        case .partialLiquid: "Liquid water covers some, but less than 80%, of the surface."
        case .globalOcean: "Liquid water covers at least 80% of the surface."
        case .steam: "Water is present and the visible-boundary temperature exceeds 373 K."
        case .inaccessible: "A deep atmosphere prevents a surface-water assessment."
        }
    }

    func label(for value: StellarActivityRegime) -> String {
        switch value {
        case .slow: "Slow activity track"
        case .median: "Median activity track"
        case .fast: "Fast activity track"
        }
    }

    func label(for value: MoonFormationOrigin) -> String {
        switch value {
        case .circumplanetaryDisk: "Circumplanetary disk"
        case .giantImpact: "Giant impact"
        }
    }

    func label(for value: StarSystemGenerationModelVersion) -> String {
        switch value {
        case .coreAccretionLiteV1: "Core Accretion Lite V1"
        }
    }

    func errorMessage(for error: StarSystemGenerationError) -> String {
        switch error {
        case .noFundedEmbryos:
            "The disk could not fund any planetary embryos for this seed."
        case .inconsistentModelVersion:
            "The generator model and its stored policy do not match."
        case .invalidPolicy:
            "The selected generation policy is invalid."
        case .invalidStar:
            "The generated star failed validation."
        case .invalidDisk:
            "The generated protoplanetary disk failed validation."
        case .invalidFormationLedger:
            "The generated formation ledger failed validation."
        case .invalidResolvedPlanetSelection:
            "The resolved planet selection failed validation."
        case .duplicateBodyID(let id):
            "The system contains duplicate body identity \(bodyID(id))."
        case .planetsNotOrdered:
            "The resolved planets are not ordered by orbital distance."
        case .invalidPlanet(let id):
            "Planet \(bodyID(id)) failed validation."
        case .invalidMoon(let id):
            "Moon \(bodyID(id)) failed validation."
        case .inconsistentDerivedBody(let id):
            "Body \(bodyID(id)) does not match its derived physical facts."
        case .unstablePlanetPair(let inner, let outer):
            "Planets \(bodyID(inner)) and \(bodyID(outer)) do not have stable clearance."
        case .unstableMoonPair(let parent, let inner, let outer):
            "Moons \(bodyID(inner)) and \(bodyID(outer)) are unstable around \(bodyID(parent))."
        case .massConservationFailure(let budget):
            "The \(budget == .solids ? "solid" : "hydrogen-helium") mass budget did not close."
        }
    }
}
