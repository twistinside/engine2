/// Identifies whether a system runs every step or only while simulation is active.
enum SimulationScheduleLane: String, Codable, CaseIterable, Sendable {
    case always
    case simulation
}
