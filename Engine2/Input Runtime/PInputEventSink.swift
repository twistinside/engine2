/// Receives platform-neutral events from an input host adapter.
protocol PInputEventSink: AnyObject {
    func receive(_ event: InputEvent)
}
