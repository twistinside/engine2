import Testing
@testable import Engine2

struct MissileTests {
    @Test func rejectsRadiusThatUnderflowsThePresentationScale() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let world = World()
                let owner = Entity(in: world, from: .empty)
                _ = Missile(
                    in: world,
                    ownerEntityID: owner.id,
                    position: .zero,
                    velocity: .zero,
                    radius: 1e-100,
                    lifetime: 5
                )
            }
        }
    }
}
