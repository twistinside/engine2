/// Durable full generational entity identity used by Render trace records.
nonisolated struct RenderTraceEntityIDRecord: Codable, Equatable, Sendable {
    let index: Int
    let generation: Int

    /// Reconstructs the full entity identity after validation succeeds.
    var value: EntityID {
        EntityID(index: index, generation: generation)
    }

    /// Captures one valid domain entity identity.
    init(_ id: EntityID) throws(RenderTraceValidationError) {
        try self.init(index: id.index, generation: id.generation)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            index: container.decode(Int.self, forKey: .index),
            generation: container.decode(Int.self, forKey: .generation)
        )
    }

    private init(
        index: Int,
        generation: Int
    ) throws(RenderTraceValidationError) {
        guard index >= 0 else {
            throw .invalidEntityIndex
        }
        guard generation >= 0 else {
            throw .invalidEntityGeneration
        }

        self.index = index
        self.generation = generation
    }

    private enum CodingKeys: String, CodingKey {
        case index
        case generation
    }
}
