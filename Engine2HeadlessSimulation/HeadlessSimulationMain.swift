import Darwin
import Foundation

/// Process entry point for the independent headless Simulation executable.
@main
struct HeadlessSimulationMain {
    static func main() async {
        do {
            let configuration = try HeadlessSimulationConfiguration(
                environment: ProcessInfo.processInfo.environment
            )
            let runner = HeadlessSimulationRunner(configuration: configuration)
            print(try await runner.run())
        } catch {
            FileHandle.standardError.write(
                Data("Engine2 headless Simulation failed: \(error)\n".utf8)
            )
            Darwin.exit(EXIT_FAILURE)
        }
    }
}
