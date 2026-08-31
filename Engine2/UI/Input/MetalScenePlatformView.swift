import AppKit
import MetalKit
import simd

/// Single AppKit scene surface shared by rendering and physical input ingress.
///
/// `MetalRenderer` uses the inherited `MTKView` drawable through its delegate.
/// This adapter independently forwards physical host events to `InputRuntime`;
/// it owns no bindings, semantic mapping, gameplay decisions, or rendering.
final class MetalScenePlatformView: MTKView {
    weak var inputSink: (any PInputEventSink)?

    private var viewportSize: SIMD2<Float> {
        SIMD2<Float>(Float(bounds.width), Float(bounds.height))
    }

    override var acceptsFirstResponder: Bool {
        inputSink != nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let window {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didResignKeyNotification,
                object: window
            )
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey(_:)),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
        }
        if inputSink != nil {
            window?.makeFirstResponder(self)
        }
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            submitFocusLost()
        }
        return didResign
    }

    override func mouseDown(with event: NSEvent) {
        guard let inputSink else {
            super.mouseDown(with: event)
            return
        }

        window?.makeFirstResponder(self)
        inputSink.receive(
            .mouseButtonDown(
                .left,
                position: pointerPosition(from: event),
                viewportSize: viewportSize
            )
        )
    }

    override func mouseDragged(with event: NSEvent) {
        guard inputSink != nil else {
            super.mouseDragged(with: event)
            return
        }

        submitMouseDrag(event)
    }

    override func mouseUp(with event: NSEvent) {
        guard let inputSink else {
            super.mouseUp(with: event)
            return
        }

        inputSink.receive(
            .mouseButtonUp(
                .left,
                position: pointerPosition(from: event),
                viewportSize: viewportSize
            )
        )
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let inputSink else {
            super.rightMouseDown(with: event)
            return
        }

        window?.makeFirstResponder(self)
        inputSink.receive(
            .mouseButtonDown(
                .right,
                position: pointerPosition(from: event),
                viewportSize: viewportSize
            )
        )
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard inputSink != nil else {
            super.rightMouseDragged(with: event)
            return
        }

        submitMouseDrag(event)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard let inputSink else {
            super.rightMouseUp(with: event)
            return
        }

        inputSink.receive(
            .mouseButtonUp(
                .right,
                position: pointerPosition(from: event),
                viewportSize: viewportSize
            )
        )
    }

    override func otherMouseDown(with event: NSEvent) {
        guard let inputSink else {
            super.otherMouseDown(with: event)
            return
        }

        window?.makeFirstResponder(self)
        inputSink.receive(
            .mouseButtonDown(
                mouseButton(for: event.buttonNumber),
                position: pointerPosition(from: event),
                viewportSize: viewportSize
            )
        )
    }

    override func otherMouseDragged(with event: NSEvent) {
        guard inputSink != nil else {
            super.otherMouseDragged(with: event)
            return
        }

        submitMouseDrag(event)
    }

    override func otherMouseUp(with event: NSEvent) {
        guard let inputSink else {
            super.otherMouseUp(with: event)
            return
        }

        inputSink.receive(
            .mouseButtonUp(
                mouseButton(for: event.buttonNumber),
                position: pointerPosition(from: event),
                viewportSize: viewportSize
            )
        )
    }

    override func scrollWheel(with event: NSEvent) {
        guard let inputSink else {
            super.scrollWheel(with: event)
            return
        }

        inputSink.receive(
            .scroll(
                delta: SIMD2<Float>(
                    Float(event.scrollingDeltaX),
                    Float(event.scrollingDeltaY)
                )
            )
        )
    }

    override func keyDown(with event: NSEvent) {
        guard let inputSink else {
            super.keyDown(with: event)
            return
        }

        guard !event.isARepeat else {
            return
        }

        inputSink.receive(
            .keyDown(
                KeyboardKey(
                    keyCode: event.keyCode,
                    charactersIgnoringModifiers: event.charactersIgnoringModifiers
                )
            )
        )
    }

    override func keyUp(with event: NSEvent) {
        guard let inputSink else {
            super.keyUp(with: event)
            return
        }

        inputSink.receive(
            .keyUp(
                KeyboardKey(
                    keyCode: event.keyCode,
                    charactersIgnoringModifiers: event.charactersIgnoringModifiers
                )
            )
        )
    }

    private func submitMouseDrag(_ event: NSEvent) {
        inputSink?.receive(
            .mouseDragged(
                delta: SIMD2<Float>(Float(event.deltaX), Float(event.deltaY)),
                position: pointerPosition(from: event),
                viewportSize: viewportSize
            )
        )
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        submitFocusLost()
    }

    private func submitFocusLost() {
        inputSink?.receive(.focusLost)
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
