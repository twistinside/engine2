/// Independently keyed deterministic random domain within one generation run.
///
/// Raw values are part of the model-version contract. Adding draws in one
/// domain cannot shift values consumed by another domain.
nonisolated enum StarSystemRandomDomain: UInt64, Sendable {
    case star = 0x7A6A_0D15_4A4F_4D01
    case disk = 0x7A6A_0D15_4A4F_4D02
    case embryos = 0x7A6A_0D15_4A4F_4D03
    case formation = 0x7A6A_0D15_4A4F_4D04
    case orbitalExcitation = 0x7A6A_0D15_4A4F_4D05
    case moons = 0x7A6A_0D15_4A4F_4D06
    case dynamicalClearing = 0x7A6A_0D15_4A4F_4D07
}
