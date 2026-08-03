/// Supported process-environment override for the headless workload.
///
/// Raw strings are required because Xcode schemes and process environments
/// exchange configuration through string keys.
enum HeadlessSimulationEnvironmentKey: String {
    case entityCount = "ENGINE2_HEADLESS_ENTITY_COUNT"
    case measuredTickCount = "ENGINE2_HEADLESS_MEASURED_TICKS"
    case warmupTickCount = "ENGINE2_HEADLESS_WARMUP_TICKS"
}
