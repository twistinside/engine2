import Darwin
import Foundation

/// Process entry point for file-driven Simulation replay and trace recording.
@main
struct SimulationReplayMain {
    static func main() async {
        do {
            let command = try SimulationReplayCommandConfiguration(
                arguments: CommandLine.arguments
            )
            let replayFile = try SimulationReplayReader().read(
                from: command.replayFileURL
            )
            let result = try await SimulationReplayDriver(
                file: replayFile,
                expectedContentIdentifier: BasicGameRecording.contentIdentifier,
                worldBuilder: BasicWorldBuilder(),
                configuration: .basicGame
            ).run()

            var recordedTracePath: String?
            if let outputURL = command.renderTraceOutputURL {
                let settings = OffscreenRenderSettings(
                    size: try RenderPixelSize(width: 640, height: 360),
                    outputMode: .surface,
                    exposure: .validation
                )
                let trace = try RenderTrace(
                    contentIdentifier:
                        BasicGameRecording.contentIdentifier,
                    simulationCameraViewpointID: RenderViewpointID(),
                    presentationSnapshots: result.presentationSnapshots,
                    settings: settings
                )
                try RenderTraceJSONWriter.write(trace, to: outputURL)
                recordedTracePath = outputURL.path
            }

            print(
                """
                Engine2 Simulation Replay
                  recording: \(result.recordingID)
                  recorded session: \(result.originalSessionID?.rawValue.uuidString ?? "unspecified")
                  replay session: \(result.replaySessionID.rawValue.uuidString)
                  completed ticks: \(result.terminalPresentationSnapshot.cursor.tick.rawValue)
                  presentations: \(result.presentationSnapshots.count)
                  render trace: \(recordedTracePath ?? "not requested")
                """
            )
        } catch {
            FileHandle.standardError.write(
                Data("Engine2 Simulation replay failed: \(error)\n".utf8)
            )
            Darwin.exit(EXIT_FAILURE)
        }
    }
}
