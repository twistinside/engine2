import Foundation

/// Consumer-owned compatibility identity carried by durable replay and render files.
///
/// The vocabulary is intentionally open because external Game Content defines its
/// own worlds, asset identities, and compatibility policy. Consumers must change
/// this value whenever a file can no longer be interpreted against their content.
nonisolated struct RecordingContentIdentifier: Codable, Hashable, RawRepresentable, Sendable {
    let rawValue: String

    /// Constructs a trusted nonempty compatibility identity.
    init(rawValue: String) {
        precondition(
            rawValue.isEmpty == false,
            "A recording content identifier must not be empty."
        )
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard rawValue.isEmpty == false else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "A recording content identifier must not be empty."
            )
        }
        self.rawValue = rawValue
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
