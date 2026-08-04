/// Durable, validated representation of one complete immutable Input publication.
///
/// Arrays encode runtime sets in stable sorted order. Decoding rejects duplicate
/// values rather than silently changing the recorded publication.
nonisolated struct SimulationReplayInputSnapshot: Equatable, Sendable {
    let revision: SimulationReplayInputRevision
    let pointerPosition: SimulationReplayVector2
    let pointerMotionTotal: SimulationReplayVector2
    let scrollTotal: SimulationReplayVector2
    let pressedMouseButtons: [SimulationReplayMouseButton]
    let pressedKeys: [SimulationReplayKeyboardKey]

    var inputSnapshot: InputSnapshot {
        InputSnapshot(
            revision: revision.inputRevision,
            pointerPosition: pointerPosition.inputValue,
            pointerMotionTotal: pointerMotionTotal.inputValue,
            scrollTotal: scrollTotal.inputValue,
            pressedMouseButtons: Set(
                pressedMouseButtons.map(\.inputValue)
            ),
            pressedKeys: Set(
                pressedKeys.map(\.inputValue)
            )
        )
    }

    init(
        revision: SimulationReplayInputRevision,
        pointerPosition: SimulationReplayVector2,
        pointerMotionTotal: SimulationReplayVector2,
        scrollTotal: SimulationReplayVector2,
        pressedMouseButtons: [SimulationReplayMouseButton],
        pressedKeys: [SimulationReplayKeyboardKey]
    ) throws(SimulationReplayError) {
        guard Set(pressedMouseButtons).count == pressedMouseButtons.count else {
            throw .duplicateMouseButtons
        }
        guard Set(pressedKeys).count == pressedKeys.count else {
            throw .duplicateKeyboardKeys
        }

        self.revision = revision
        self.pointerPosition = pointerPosition
        self.pointerMotionTotal = pointerMotionTotal
        self.scrollTotal = scrollTotal
        self.pressedMouseButtons = pressedMouseButtons.sorted()
        self.pressedKeys = pressedKeys.sorted()
    }

    init(recording snapshot: InputSnapshot) throws(SimulationReplayError) {
        try self.init(
            revision: SimulationReplayInputRevision(
                recording: snapshot.revision
            ),
            pointerPosition: SimulationReplayVector2(
                recording: snapshot.pointerPosition
            ),
            pointerMotionTotal: SimulationReplayVector2(
                recording: snapshot.pointerMotionTotal
            ),
            scrollTotal: SimulationReplayVector2(
                recording: snapshot.scrollTotal
            ),
            pressedMouseButtons: snapshot.pressedMouseButtons.map {
                SimulationReplayMouseButton(recording: $0)
            },
            pressedKeys: snapshot.pressedKeys.map {
                SimulationReplayKeyboardKey(recording: $0)
            }
        )
    }
}

extension SimulationReplayInputSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case pointerMotionTotal
        case pointerPosition
        case pressedKeys
        case pressedMouseButtons
        case revision
        case scrollTotal
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            try self.init(
                revision: container.decode(
                    SimulationReplayInputRevision.self,
                    forKey: .revision
                ),
                pointerPosition: container.decode(
                    SimulationReplayVector2.self,
                    forKey: .pointerPosition
                ),
                pointerMotionTotal: container.decode(
                    SimulationReplayVector2.self,
                    forKey: .pointerMotionTotal
                ),
                scrollTotal: container.decode(
                    SimulationReplayVector2.self,
                    forKey: .scrollTotal
                ),
                pressedMouseButtons: container.decode(
                    [SimulationReplayMouseButton].self,
                    forKey: .pressedMouseButtons
                ),
                pressedKeys: container.decode(
                    [SimulationReplayKeyboardKey].self,
                    forKey: .pressedKeys
                )
            )
        } catch let error as SimulationReplayError {
            throw DecodingError.dataCorruptedError(
                forKey: .revision,
                in: container,
                debugDescription: error.description
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pointerMotionTotal, forKey: .pointerMotionTotal)
        try container.encode(pointerPosition, forKey: .pointerPosition)
        try container.encode(pressedKeys, forKey: .pressedKeys)
        try container.encode(pressedMouseButtons, forKey: .pressedMouseButtons)
        try container.encode(revision, forKey: .revision)
        try container.encode(scrollTotal, forKey: .scrollTotal)
    }
}
