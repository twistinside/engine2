import AppKit
import MetalKit
import simd

/// MetalKit view subclass that translates AppKit events into engine input events.
final class InputMetalView: MTKView {
    weak var inputSink: (any PInputEventSink)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        inputSink?.receive(.mouseButtonDown(.left, position: pointerPosition(from: event)))
    }

    override func mouseDragged(with event: NSEvent) {
        inputSink?.receive(
            .mouseDragged(
                delta: SIMD2<Float>(Float(event.deltaX), Float(event.deltaY)),
                position: pointerPosition(from: event)
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        inputSink?.receive(.mouseButtonUp(.left, position: pointerPosition(from: event)))
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        inputSink?.receive(.mouseButtonDown(.right, position: pointerPosition(from: event)))
    }

    override func rightMouseUp(with event: NSEvent) {
        inputSink?.receive(.mouseButtonUp(.right, position: pointerPosition(from: event)))
    }

    override func otherMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        inputSink?.receive(
            .mouseButtonDown(
                mouseButton(for: event.buttonNumber),
                position: pointerPosition(from: event)
            )
        )
    }

    override func otherMouseUp(with event: NSEvent) {
        inputSink?.receive(
            .mouseButtonUp(
                mouseButton(for: event.buttonNumber),
                position: pointerPosition(from: event)
            )
        )
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = SIMD2<Float>(
            Float(event.scrollingDeltaX),
            Float(event.scrollingDeltaY)
        )
        inputSink?.receive(.scroll(delta: delta))
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else {
            return
        }

        let key = KeyboardKey(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers
        )
        inputSink?.receive(.keyDown(key))
    }

    override func keyUp(with event: NSEvent) {
        let key = KeyboardKey(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers
        )
        inputSink?.receive(.keyUp(key))
    }

    private func pointerPosition(from event: NSEvent) -> SIMD2<Float> {
        let position = convert(event.locationInWindow, from: nil)
        return SIMD2<Float>(Float(position.x), Float(position.y))
    }

    private func mouseButton(for buttonNumber: Int) -> MouseButton {
        switch buttonNumber {
        case 2: .middle
        default: .other(buttonNumber)
        }
    }
}
