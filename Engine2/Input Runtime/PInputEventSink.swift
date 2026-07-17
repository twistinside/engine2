/// Receives platform-neutral events from an input host adapter.
@MainActor
protocol PInputEventSink: AnyObject {
    func receive(_ event: InputEvent)
}
