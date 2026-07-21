import Testing
@testable import Engine2

struct ManualExposureTests {
    @Test func validationExposureLeavesSceneLinearValuesUnscaled() {
        // Milestone 3 treats exposure as a direct multiplier rather than camera
        // stops. A unit validation value therefore preserves the HDR scene input
        // before the presentation shader applies Reinhard tone mapping.
        #expect(ManualExposure.validation.multiplier == 1)
    }

    @Test func finiteNonnegativeMultipliersArePreservedExactly() {
        // Zero is a useful deliberate blackout and values above one brighten the
        // scene. Keeping both endpoints intact proves this domain value does not
        // hide an undocumented clamp or convert the multiplier into stops.
        let black = ManualExposure(multiplier: 0)
        let half = ManualExposure(multiplier: 0.5)
        let bright = ManualExposure(multiplier: 2)

        #expect(black.multiplier == 0)
        #expect(half.multiplier == 0.5)
        #expect(bright.multiplier == 2)
        #expect(half == ManualExposure(multiplier: 0.5))
    }
}
