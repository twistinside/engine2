//
//  InputMetalView.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

import AppKit
import MetalKit
import simd

/// MetalKit view subclass that translates AppKit events into engine input events.
final class InputMetalView: MTKView {
    var inputHandler: ((InputEvent) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        inputHandler?(.mouseButtonDown(.left, position: pointerPosition(from: event)))
    }

    override func mouseDragged(with event: NSEvent) {
        inputHandler?(
            .mouseDragged(
                delta: pointerDelta(from: event),
                position: pointerPosition(from: event)
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        inputHandler?(.mouseButtonUp(.left, position: pointerPosition(from: event)))
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        inputHandler?(.mouseButtonDown(.right, position: pointerPosition(from: event)))
    }

    override func rightMouseUp(with event: NSEvent) {
        inputHandler?(.mouseButtonUp(.right, position: pointerPosition(from: event)))
    }

    override func otherMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        inputHandler?(
            .mouseButtonDown(
                mouseButton(for: event.buttonNumber),
                position: pointerPosition(from: event)
            )
        )
    }

    override func otherMouseUp(with event: NSEvent) {
        inputHandler?(
            .mouseButtonUp(
                mouseButton(for: event.buttonNumber),
                position: pointerPosition(from: event)
            )
        )
    }

    override func scrollWheel(with event: NSEvent) {
        inputHandler?(
            .scroll(
                delta: SIMD2<Float>(
                    Float(event.scrollingDeltaX),
                    Float(event.scrollingDeltaY)
                )
            )
        )
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else {
            return
        }

        inputHandler?(
            .keyDown(
                KeyboardKey.make(
                    keyCode: event.keyCode,
                    charactersIgnoringModifiers: event.charactersIgnoringModifiers
                )
            )
        )
    }

    override func keyUp(with event: NSEvent) {
        inputHandler?(
            .keyUp(
                KeyboardKey.make(
                    keyCode: event.keyCode,
                    charactersIgnoringModifiers: event.charactersIgnoringModifiers
                )
            )
        )
    }

    private func pointerPosition(from event: NSEvent) -> SIMD2<Float> {
        let position = convert(event.locationInWindow, from: nil)
        return SIMD2<Float>(Float(position.x), Float(position.y))
    }

    private func pointerDelta(from event: NSEvent) -> SIMD2<Float> {
        SIMD2<Float>(Float(event.deltaX), Float(event.deltaY))
    }

    private func mouseButton(for buttonNumber: Int) -> InputState.MouseButton {
        switch buttonNumber {
        case 2: .middle
        default: .other(buttonNumber)
        }
    }
}
