import AppKit
import CoreGraphics
import Testing
@testable import Engine2

struct InputMetalViewTests {
    @MainActor
    @Test func acceptsKeyboardFocusAndTranslatesKeyTransitions() throws {
        let view = InputMetalView(frame: .zero, device: nil)
        // InputMetalView deliberately retains its sink weakly, so the host
        // owns the adapter destination for as long as events may arrive.
        let inputSink = RecordingInputEventSink()
        view.inputSink = inputSink
        let keyDown = try #require(
            makeKeyEvent(type: .keyDown, isRepeat: false)
        )
        let keyUp = try #require(
            makeKeyEvent(type: .keyUp, isRepeat: false)
        )

        view.keyDown(with: keyDown)
        view.keyUp(with: keyUp)

        #expect(view.acceptsFirstResponder)
        #expect(inputSink.receivedEvents.count == 2)

        guard case let .keyDown(downKey) = inputSink.receivedEvents[0],
              case let .keyUp(upKey) = inputSink.receivedEvents[1]
        else {
            Issue.record("Expected key-down followed by key-up events.")
            return
        }

        #expect(downKey == KeyboardKey(keyCode: 13, displayName: "W"))
        #expect(upKey == downKey)
    }

    @MainActor
    @Test func repeatedKeyDownIsIgnored() throws {
        let view = InputMetalView(frame: .zero, device: nil)
        let inputSink = RecordingInputEventSink()
        view.inputSink = inputSink
        let repeatedKeyDown = try #require(
            makeKeyEvent(type: .keyDown, isRepeat: true)
        )

        view.keyDown(with: repeatedKeyDown)

        #expect(inputSink.receivedEvents.isEmpty)
    }

    @MainActor
    @Test func platformEventsPublishDirectlyThroughInputRuntime() throws {
        let view = InputMetalView(frame: .zero, device: nil)
        let inputRuntime = InputRuntime()
        inputRuntime.start()
        view.inputSink = inputRuntime
        let startingRevision = inputRuntime.latestInputSnapshot.revision
        let keyDown = try #require(
            makeKeyEvent(type: .keyDown, isRepeat: false)
        )
        let keyUp = try #require(
            makeKeyEvent(type: .keyUp, isRepeat: false)
        )

        view.keyDown(with: keyDown)

        #expect(inputRuntime.latestInputSnapshot.revision != startingRevision)
        #expect(
            inputRuntime.latestInputSnapshot.pressedKeys
                == [KeyboardKey(keyCode: 13, displayName: "W")]
        )

        view.keyUp(with: keyUp)

        #expect(inputRuntime.latestInputSnapshot.pressedKeys.isEmpty)
        inputRuntime.stop()
    }

    @MainActor
    @Test func dragAndScrollPublishTheirExactDeltasThroughInputRuntime() throws {
        let view = InputMetalView(frame: .zero, device: nil)
        let inputRuntime = InputRuntime()
        inputRuntime.start()
        defer { inputRuntime.stop() }
        view.inputSink = inputRuntime

        let dragEvent = try makeLeftDragEvent(
            location: CGPoint(x: 30, y: 40),
            deltaX: 7,
            deltaY: -9
        )
        view.mouseDragged(with: dragEvent)

        #expect(
            inputRuntime.latestInputSnapshot.pointerPosition
                == SIMD2<Float>(30, 40)
        )
        #expect(
            inputRuntime.latestInputSnapshot.pointerMotionTotal
                == SIMD2<Float>(7, -9)
        )

        let scrollEvent = try makePixelScrollEvent(
            horizontal: 5,
            vertical: -7
        )
        #expect(scrollEvent.hasPreciseScrollingDeltas)
        #expect(scrollEvent.scrollingDeltaX == 5)
        #expect(scrollEvent.scrollingDeltaY == -7)

        view.scrollWheel(with: scrollEvent)

        #expect(
            inputRuntime.latestInputSnapshot.scrollTotal
                == SIMD2<Float>(5, -7)
        )
    }

    @MainActor
    private func makeKeyEvent(type: NSEvent.EventType, isRepeat: Bool) -> NSEvent? {
        NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "w",
            charactersIgnoringModifiers: "w",
            isARepeat: isRepeat,
            keyCode: 13
        )
    }

    @MainActor
    private func makeLeftDragEvent(location: CGPoint, deltaX: Int64, deltaY: Int64) throws -> NSEvent {
        let baseEvent = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDragged,
                location: location,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )
        let cgEvent = try #require(baseEvent.cgEvent)
        cgEvent.setIntegerValueField(.mouseEventDeltaX, value: deltaX)
        cgEvent.setIntegerValueField(.mouseEventDeltaY, value: deltaY)
        return try #require(NSEvent(cgEvent: cgEvent))
    }

    @MainActor
    private func makePixelScrollEvent(horizontal: Int32, vertical: Int32) throws -> NSEvent {
        let cgEvent = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: vertical,
                wheel2: horizontal,
                wheel3: 0
            )
        )
        return try #require(NSEvent(cgEvent: cgEvent))
    }
}
