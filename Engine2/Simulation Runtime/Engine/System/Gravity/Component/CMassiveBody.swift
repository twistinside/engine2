/// Positive mass and physical contact radius for one gravity source.
///
/// `SGravity` treats every entity with this component and `CPosition` as a
/// source. A source receives gravity only when the same entity also has
/// `CMotion`.
struct CMassiveBody: PComponent {
    let mass: AstronomicalMass
    let physicalRadius: AstronomicalDistance

    init(mass: AstronomicalMass, physicalRadius: AstronomicalDistance) {
        precondition(
            mass.kilograms.isFinite && mass.kilograms > 0,
            "A massive body must have positive finite mass."
        )
        precondition(
            physicalRadius.meters.isFinite && physicalRadius.meters > 0,
            "A massive body must have a positive finite physical radius."
        )
        self.mass = mass
        self.physicalRadius = physicalRadius
    }
}

extension CMassiveBody: Codable {
    private enum CodingKeys: String, CodingKey {
        case mass
        case physicalRadius
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mass = try container.decode(AstronomicalMass.self, forKey: .mass)
        let physicalRadius = try container.decode(AstronomicalDistance.self, forKey: .physicalRadius)
        guard mass.kilograms.isFinite, mass.kilograms > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .mass,
                in: container,
                debugDescription: "A massive body must have positive finite mass."
            )
        }
        guard physicalRadius.meters.isFinite, physicalRadius.meters > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .physicalRadius,
                in: container,
                debugDescription: "A massive body must have a positive finite physical radius."
            )
        }
        self.init(mass: mass, physicalRadius: physicalRadius)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mass, forKey: .mass)
        try container.encode(physicalRadius, forKey: .physicalRadius)
    }
}
