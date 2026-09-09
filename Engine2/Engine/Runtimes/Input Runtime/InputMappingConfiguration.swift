import simd

/// Validated physical-to-semantic mapping owned by an Input Runtime.
///
/// Game Content selects one immutable value when it constructs a Runtime
/// Assembly. Simulation receives only the resulting semantic snapshot and
/// never observes these physical bindings or sensitivities.
nonisolated struct InputMappingConfiguration: Equatable, Sendable {
    /// Standard controls tuned for the compact example game's camera scale.
    static let basicGame = Self(
        leftKeyCodes: [0, 123],
        rightKeyCodes: [2, 124],
        upwardKeyCodes: [13, 126],
        downwardKeyCodes: [1, 125],
        interactionKeyCodes: [49],
        fireKeyCodes: [46],
        selectionButton: .left,
        pointerOrbitSensitivity: 0.01,
        scrollZoomSensitivity: 0.04
    )

    /// Standard controls tuned for the mining slice's kilometer-scale scene.
    static let miningGame = Self(
        leftKeyCodes: [0, 123],
        rightKeyCodes: [2, 124],
        upwardKeyCodes: [13, 126],
        downwardKeyCodes: [1, 125],
        interactionKeyCodes: [49],
        fireKeyCodes: [46],
        selectionButton: .left,
        pointerOrbitSensitivity: 0.01,
        scrollZoomSensitivity: 4
    )

    let leftKeyCodes: Set<UInt16>
    let rightKeyCodes: Set<UInt16>
    let upwardKeyCodes: Set<UInt16>
    let downwardKeyCodes: Set<UInt16>
    let interactionKeyCodes: Set<UInt16>
    let fireKeyCodes: Set<UInt16>
    let selectionButton: MouseButton
    let pointerOrbitSensitivity: Float
    let scrollZoomSensitivity: Float

    init(
        leftKeyCodes: Set<UInt16>,
        rightKeyCodes: Set<UInt16>,
        upwardKeyCodes: Set<UInt16>,
        downwardKeyCodes: Set<UInt16>,
        interactionKeyCodes: Set<UInt16>,
        fireKeyCodes: Set<UInt16>,
        selectionButton: MouseButton,
        pointerOrbitSensitivity: Float,
        scrollZoomSensitivity: Float
    ) {
        precondition(pointerOrbitSensitivity.isFinite, "Pointer orbit sensitivity must be finite.")
        precondition(scrollZoomSensitivity.isFinite, "Scroll zoom sensitivity must be finite.")

        self.leftKeyCodes = leftKeyCodes
        self.rightKeyCodes = rightKeyCodes
        self.upwardKeyCodes = upwardKeyCodes
        self.downwardKeyCodes = downwardKeyCodes
        self.interactionKeyCodes = interactionKeyCodes
        self.fireKeyCodes = fireKeyCodes
        self.selectionButton = selectionButton
        self.pointerOrbitSensitivity = pointerOrbitSensitivity
        self.scrollZoomSensitivity = scrollZoomSensitivity
    }
}
