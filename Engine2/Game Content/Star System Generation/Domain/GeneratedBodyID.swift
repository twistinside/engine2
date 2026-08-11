/// Stable identity assigned during formation and retained through sorting.
///
/// A merger keeps the smaller progenitor identity. Satellite identities occupy
/// a disjoint high-bit namespace derived from their parent identity.
nonisolated struct GeneratedBodyID: Codable, Comparable, Equatable, Hashable, RawRepresentable, Sendable {
    private static let moonNamespaceBit: UInt64 = 0x8000_0000_0000_0000
    private static let moonParentMask: UInt64 = 0x0000_00FF_FFFF_FFFF
    private static let moonOrdinalMask: UInt64 = 0x0000_0000_0000_FFFF
    private static let moonPayloadMask: UInt64 = 0x00FF_FFFF_FFFF_FFFF

    let rawValue: UInt64

    /// Whether this value is a canonical identity in the planet namespace.
    var isPlanet: Bool {
        rawValue > 0 && rawValue <= Self.moonParentMask
    }

    /// The parent encoded by a canonical moon identity, or `nil` for every other bit pattern.
    var parentPlanetID: GeneratedBodyID? {
        guard let moonPayload else {
            return nil
        }
        return GeneratedBodyID(rawValue: moonPayload.parentRawValue)
    }

    /// The zero-based formation index encoded by a canonical moon identity.
    var moonFormationIndex: Int? {
        moonPayload?.formationIndex
    }

    private var moonPayload: (parentRawValue: UInt64, formationIndex: Int)? {
        let allowedBits = Self.moonNamespaceBit | Self.moonPayloadMask
        guard rawValue & Self.moonNamespaceBit != 0,
              rawValue & ~allowedBits == 0 else {
            return nil
        }
        let parentRawValue = (rawValue >> 16) & Self.moonParentMask
        let ordinal = rawValue & Self.moonOrdinalMask
        guard parentRawValue > 0, ordinal > 0 else {
            return nil
        }
        return (parentRawValue, Int(ordinal - 1))
    }

    init(rawValue: UInt64) {
        precondition(rawValue > 0, "A generated body identity must be positive.")
        self.rawValue = rawValue
    }

    /// Returns the canonical identity for one zero-based formation index.
    static func planet(formationIndex: Int) -> GeneratedBodyID {
        precondition(formationIndex >= 0, "A planet formation index cannot be negative.")
        let rawValue = UInt64(formationIndex) + 1
        precondition(rawValue <= moonParentMask, "A planet identity must fit in the moon parent field.")
        return GeneratedBodyID(rawValue: rawValue)
    }

    /// Returns the canonical moon identity for one parent and zero-based formation index.
    static func moon(parent: GeneratedBodyID, formationIndex: Int) -> GeneratedBodyID {
        precondition(parent.isPlanet, "A moon parent must have a canonical planet identity.")
        precondition(formationIndex >= 0, "A moon formation index cannot be negative.")
        precondition(
            UInt64(formationIndex) < moonOrdinalMask,
            "A moon formation index must fit in the moon ordinal field."
        )
        let ordinal = UInt64(formationIndex) + 1
        return GeneratedBodyID(
            rawValue: moonNamespaceBit
                | (parent.rawValue << 16)
                | ordinal
        )
    }

    static func < (lhs: GeneratedBodyID, rhs: GeneratedBodyID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
