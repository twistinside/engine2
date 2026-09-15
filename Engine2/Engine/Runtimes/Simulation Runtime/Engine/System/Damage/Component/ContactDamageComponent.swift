/// Positive outgoing damage applied to a health-bearing recipient at the source's first eligible contact.
///
/// The amount does not imply source consumption, ownership, lifetime, or recipient targetability.
struct ContactDamageComponent: Component {
    let amount: HitPoints

    init(amount: HitPoints) {
        precondition(amount.rawValue > 0, "Contact damage must be positive.")
        self.amount = amount
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let amount = try values.decode(HitPoints.self, forKey: .amount)
        guard amount.rawValue > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .amount,
                in: values,
                debugDescription: "Contact damage must be positive."
            )
        }
        self.amount = amount
    }
}
