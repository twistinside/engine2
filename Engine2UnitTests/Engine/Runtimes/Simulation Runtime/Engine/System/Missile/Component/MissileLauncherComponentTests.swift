import Testing
@testable import Engine2

struct MissileLauncherComponentTests {
    @Test func rejectsRadiusThatUnderflowsThePresentationScale() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = MissileLauncherComponent(speed: 100, lifetime: 5, radius: 1e-100)
            }
        }
    }
}
