import Testing
@testable import Engine2

struct InputMappingConfigurationTests {
    @Test func namedMappingsShareBindingsAndSelectScaleAppropriateZoom() {
        let basicConfiguration = InputMappingConfiguration.basicGame
        let miningConfiguration = InputMappingConfiguration.miningGame

        #expect(miningConfiguration.leftKeyCodes == [0, 123])
        #expect(miningConfiguration.rightKeyCodes == [2, 124])
        #expect(miningConfiguration.upwardKeyCodes == [13, 126])
        #expect(miningConfiguration.downwardKeyCodes == [1, 125])
        #expect(miningConfiguration.interactionKeyCodes == [49])
        #expect(miningConfiguration.selectionButton == .left)
        #expect(miningConfiguration.pointerOrbitSensitivity == 0.01)
        #expect(miningConfiguration.scrollZoomSensitivity == 4)
        #expect(basicConfiguration.pointerOrbitSensitivity == 0.01)
        #expect(basicConfiguration.scrollZoomSensitivity == 0.04)
    }
}
