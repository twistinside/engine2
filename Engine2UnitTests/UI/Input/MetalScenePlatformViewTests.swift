import AppKit
import CoreGraphics
import Testing
@testable import Engine2

struct MetalScenePlatformViewTests {
    @Test func renderOnlyViewDeclinesKeyboardFocusWithoutAnInputSink() {
        let view = MetalScenePlatformView(frame: .zero, device: nil)

        #expect(view.acceptsFirstResponder == false)
    }

    @Test func acceptsKeyboardFocusAndForwardsPhysicalKeyTransitions() throws {
        let view = MetalScenePlatformView(frame: .zero, device: nil)
        // The platform view retains its sink weakly, so the host owns the
        // adapter destination for as long as physical events may arrive.
        let inputSink = RecordingInputEventSink()
        view.inputSink = inputSink
        let keyDown = try #require(makeKeyEvent(type: .keyDown, isRepeat: false))
        let keyUp = try #require(makeKeyEvent(type: .keyUp, isRepeat: false))

        view.keyDown(with: keyDown)
        view.keyUp(with: keyUp)

        #expect(view.acceptsFirstResponder)
        #expect(inputSink.receivedEvents.count == 2)

        guard case let .keyDown(downKey) = inputSink.receivedEvents[0],
              case let .keyUp(upKey) = inputSink.receivedEvents[1] else {
            Issue.record("Expected key-down followed by key-up events.")
            return
        }

        #expect(downKey == KeyboardKey(keyCode: 13, displayName: "W"))
        #expect(upKey == downKey)
    }

    @Test func repeatedKeyDownIsIgnoredByThePlatformAdapter() throws {
        let view = MetalScenePlatformView(frame: .zero, device: nil)
        let inputSink = RecordingInputEventSink()
        view.inputSink = inputSink
        let repeatedKeyDown = try #require(makeKeyEvent(type: .keyDown, isRepeat: true))

        view.keyDown(with: repeatedKeyDown)

        #expect(inputSink.receivedEvents.isEmpty)
    }

    @Test func resigningFocusClearsRuntimeHeldState() throws {
        let view = MetalScenePlatformView(frame: .zero, device: nil)
        let inputRuntime = InputRuntime()
        inputRuntime.start()
        defer { inputRuntime.stop() }
        view.inputSink = inputRuntime
        view.keyDown(with: try #require(makeKeyEvent(type: .keyDown, isRepeat: false)))

        _ = view.resignFirstResponder()

        #expect(inputRuntime.latestInputSnapshot.translation == .zero)
    }

    @Test func pointerEventsIncludePhysicalCoordinatesAndViewportSize() throws {
        let view = MetalScenePlatformView(
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            device: nil
        )
        let inputSink = RecordingInputEventSink()
        view.inputSink = inputSink
        let mouseDown = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: CGPoint(x: 25, y: 10),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )

        view.mouseDown(with: mouseDown)

        let receivedEvent = try #require(inputSink.receivedEvents.first)
        guard case let .mouseButtonDown(button, position, viewportSize) = receivedEvent else {
            Issue.record("Expected one physical mouse-down event.")
            return
        }
        #expect(button == .left)
        #expect(position == SIMD2<Float>(25, 10))
        #expect(viewportSize == SIMD2<Float>(100, 50))
    }

    @Test func platformEventsMapThroughInputRuntimeWithoutViewOwnedBindings() throws {
        let view = MetalScenePlatformView(
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            device: nil
        )
        let inputRuntime = InputRuntime()
        inputRuntime.start()
        view.inputSink = inputRuntime
        let keyDown = try #require(makeKeyEvent(type: .keyDown, isRepeat: false))
        let mouseDown = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: CGPoint(x: 25, y: 10),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )

        view.keyDown(with: keyDown)
        view.mouseDown(with: mouseDown)

        #expect(inputRuntime.latestInputSnapshot.translation == SIMD2<Float>(0, 1))
        #expect(inputRuntime.latestInputSnapshot.latestSelectionPress?.normalizedPosition == SIMD2<Float>(0.25, 0.2))
        #expect(inputRuntime.latestInputSnapshot.selectionPressCount == 1)
        inputRuntime.stop()
    }

    @Test func dragAndScrollForwardExactPhysicalDeltasForRuntimeMapping() throws {
        let view = MetalScenePlatformView(
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            device: nil
        )
        let inputRuntime = InputRuntime()
        inputRuntime.start()
        defer { inputRuntime.stop() }
        view.inputSink = inputRuntime

        view.mouseDragged(
            with: try makeLeftDragEvent(
                location: CGPoint(x: 30, y: 40),
                deltaX: 7,
                deltaY: -9
            )
        )
        let cameraOrbitTotal = inputRuntime.latestInputSnapshot.cameraOrbitTotal
        #expect(abs(cameraOrbitTotal.x - 0.07) < 0.0001)
        #expect(abs(cameraOrbitTotal.y - -0.09) < 0.0001)

        let scrollEvent = try makePixelScrollEvent(horizontal: 5, vertical: -7)
        #expect(scrollEvent.hasPreciseScrollingDeltas)
        view.scrollWheel(with: scrollEvent)

        #expect(inputRuntime.latestInputSnapshot.cameraZoomTotal == -28)
    }

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
