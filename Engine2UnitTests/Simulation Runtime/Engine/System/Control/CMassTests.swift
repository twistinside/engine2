import Testing
@testable import Engine2

struct CMassTests {
    @Test func totalMassIncludesCurrentFuelAndCargo() {
        let mass = CMass(dryMass: 10_000)
        let fuel = CFuel(capacity: 2_000, remaining: 1_250)
        let cargo = CCargo(capacity: 8_000, ore: 3_500)

        #expect(mass.totalMass(fuel: fuel, cargo: cargo) == 14_750)
    }

    @Test func totalMassTreatsAbsentStorageAsZero() {
        let mass = CMass(dryMass: 10_000)

        #expect(mass.totalMass(fuel: nil, cargo: nil) == 10_000)
    }
}
