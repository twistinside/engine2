//
//  InputEvent.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

import simd

/// Platform-neutral input events emitted by host views.
enum InputEvent {
    case mouseButtonDown(InputState.MouseButton, position: SIMD2<Float>)
    case mouseButtonUp(InputState.MouseButton, position: SIMD2<Float>)
    case mouseDragged(delta: SIMD2<Float>, position: SIMD2<Float>)
    case scroll(delta: SIMD2<Float>)
    case keyDown(KeyboardKey)
    case keyUp(KeyboardKey)
}
