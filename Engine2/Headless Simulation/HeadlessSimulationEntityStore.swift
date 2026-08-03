/// Component store whose headless-workload cardinality must remain equal to
/// the configured entity count.
enum HeadlessSimulationEntityStore: String {
    case angularMotionAccumulator
    case angularVelocity
    case motion
    case position
    case renderable
    case rotation
    case selectable
}
