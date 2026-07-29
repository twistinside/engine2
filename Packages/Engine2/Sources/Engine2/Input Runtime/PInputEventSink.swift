/// Receives platform-neutral events from an input host adapter.
public protocol PInputEventSink: AnyObject {
    func receive(_ event: InputEvent)
}
