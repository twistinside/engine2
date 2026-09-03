/// Receives platform-neutral events from an input host adapter.
protocol InputEventSink: AnyObject {
    func receive(_ event: InputEvent)
}
