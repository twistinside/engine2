@testable import Engine2

final class RecordingInputEventSink: InputEventSink {
    private(set) var receivedEvents: [InputEvent] = []

    func receive(_ event: InputEvent) {
        receivedEvents.append(event)
    }
}
