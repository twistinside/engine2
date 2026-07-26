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
        let deltaX = Float(event.deltaX)
        let deltaY = Float(event.deltaY)
        let delta = SIMD2<Float>(deltaX, deltaY)
        inputSink?.receive(
            .mouseDragged(
                delta: delta,
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
        let deltaX = Float(event.scrollingDeltaX)
        let deltaY = Float(event.scrollingDeltaY)
        let delta = SIMD2<Float>(deltaX, deltaY)
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
        let x = Float(position.x)
        let y = Float(position.y)
        return SIMD2<Float>(x, y)
    }

    private func mouseButton(for buttonNumber: Int) -> MouseButton {
        switch buttonNumber {
        case 2: .middle
        default: .other(buttonNumber)
        }
    }
}
