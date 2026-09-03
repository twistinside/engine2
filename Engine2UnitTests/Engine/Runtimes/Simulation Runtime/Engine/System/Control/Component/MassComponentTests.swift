import Testing
@testable import Engine2

struct MassComponentTests {
    @Test func totalMassIncludesCurrentFuelAndCargo() {
        let mass = MassComponent(dryMass: 10_000)
        let fuel = FuelComponent(capacity: 2_000, remaining: 1_250)
        let cargo = CargoComponent(capacity: 8_000, ore: 3_500)

        #expect(mass.totalMass(fuel: fuel, cargo: cargo) == 14_750)
    }

    @Test func totalMassTreatsAbsentStorageAsZero() {
        let mass = MassComponent(dryMass: 10_000)

        #expect(mass.totalMass(fuel: nil, cargo: nil) == 10_000)
    }
}
