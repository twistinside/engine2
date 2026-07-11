//
//  InputState.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

import simd

/// Raw device state, mapped actions, and compact per-step input history.
struct InputState {
    enum MouseButton: Hashable, Comparable {
        case left
        case right
        case middle
        case other(Int)

        var displayName: String {
            switch self {
            case .left: "LMB"
            case .right: "RMB"
            case .middle: "MMB"
            case let .other(buttonNumber): "M\(buttonNumber)"
            }
        }

        static func < (lhs: MouseButton, rhs: MouseButton) -> Bool {
            lhs.sortIndex < rhs.sortIndex
        }

        private var sortIndex: Int {
            switch self {
            case .left: 0
            case .right: 1
            case .middle: 2
            case let .other(buttonNumber): 10 + buttonNumber
            }
        }
    }

    struct Mouse {
        var position: SIMD2<Float> = .zero
        var delta: SIMD2<Float> = .zero
        var scrollDelta: SIMD2<Float> = .zero
        var buttons = Set<MouseButton>()
    }

    struct Keyboard {
        var keys = Set<KeyboardKey>()
    }

    enum GamepadButton: Hashable {
        case buttonA
        case buttonB
        case buttonX
        case buttonY
        case leftShoulder
        case rightShoulder
        case leftThumbstick
        case rightThumbstick
        case menu
        case options
        case dpadUp
        case dpadDown
        case dpadLeft
        case dpadRight
    }

    struct Gamepad {
        var leftStick: SIMD2<Float> = .zero
        var rightStick: SIMD2<Float> = .zero
        var leftTrigger: Float = 0
        var rightTrigger: Float = 0
        var buttons = Set<GamepadButton>()
    }

    struct Actions {
        var cameraOrbitDelta: SIMD2<Float> = .zero
        var cameraZoomDelta: Float = 0
    }

    var mouse = Mouse()
    var keyboard = Keyboard()
    var gamepad = Gamepad()
    var actions = Actions()
    var history: [InputHistoryEntry] = []
    var historyLimit = 60

    private var frameIndex = 0
    private var nextHistoryID = 0

    mutating func apply(_ event: InputEvent) {
        switch event {
        case let .mouseButtonDown(button, position):
            mouse.position = position
            mouse.buttons.insert(button)

        case let .mouseButtonUp(button, position):
            mouse.position = position
            mouse.buttons.remove(button)

        case let .mouseDragged(delta, position):
            mouse.position = position
            mouse.delta += delta

        case let .scroll(delta):
            mouse.scrollDelta += delta

        case let .keyDown(key):
            keyboard.keys.insert(key)

        case let .keyUp(key):
            keyboard.keys.remove(key)
        }
    }

    mutating func recordHistoryFrame() {
        frameIndex += 1

        let tokens = currentHistoryTokens()
        guard !tokens.isEmpty else {
            return
        }

        if history.first?.tokens == tokens {
            history[0].frameCount += 1
            return
        }

        let entry = InputHistoryEntry(
            id: nextHistoryID,
            frameIndex: frameIndex,
            frameCount: 1,
            tokens: tokens
        )
        nextHistoryID += 1

        history.insert(entry, at: 0)
        if history.count > historyLimit {
            history.removeLast(history.count - historyLimit)
        }
    }

    mutating func clearTransientInput() {
        mouse.delta = .zero
        mouse.scrollDelta = .zero
        actions = Actions()
    }

    func currentHistoryTokens() -> [String] {
        var tokens: [String] = []

        tokens += mouse.buttons.sorted().map(\.displayName)

        if mouse.delta != .zero {
            tokens.append("Mouse \(Self.format(delta: mouse.delta))")
        }

        if mouse.scrollDelta != .zero {
            tokens.append("Wheel:\(Self.format(signed: mouse.scrollDelta.y))")
        }

        tokens += keyboard.keys.sorted().map(\.displayName)

        return tokens
    }

    private static func format(delta: SIMD2<Float>) -> String {
        "dx:\(format(signed: delta.x)) dy:\(format(signed: delta.y))"
    }

    private static func format(signed value: Float) -> String {
        let rounded = Int(value.rounded())
        if rounded >= 0 {
            return "+\(rounded)"
        } else {
            return "\(rounded)"
        }
    }
}
