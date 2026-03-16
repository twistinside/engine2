import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(Engine2MacrosPlugin)
import Engine2MacrosPlugin

let testMacros: [String: Macro.Type] = [
    "SignpostedUpdate": SignpostedUpdateMacro.self,
]
#endif

final class Engine2MacrosTests: XCTestCase {
    func testExpansion() throws {
        #if canImport(Engine2MacrosPlugin)
        assertMacroExpansion(
            """
            struct ExampleSystem {
                @SignpostedUpdate(signposter: Self.signposter)
                func update(world: inout World, deltaTime: Float) {
                    applyMotion()
                }
            }
            """,
            expandedSource: """
            struct ExampleSystem {
                func update(world: inout World, deltaTime: Float) {
                    let __signposter = Self.signposter
                    let __state = __signposter.beginInterval("ExampleSystem.update")
                    defer {
                        __signposter.endInterval("ExampleSystem.update", __state)
                    }
                    applyMotion()
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testRejectsNonUpdateFunctions() throws {
        #if canImport(Engine2MacrosPlugin)
        assertMacroExpansion(
            """
            struct ExampleSystem {
                @SignpostedUpdate(signposter: Self.signposter)
                func tick() {}
            }
            """,
            expandedSource: """
            struct ExampleSystem {
                func tick() {}
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@SignpostedUpdate can only be attached to a function named update", line: 2, column: 5),
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testRejectsFreeFunctionUpdate() throws {
        #if canImport(Engine2MacrosPlugin)
        assertMacroExpansion(
            """
            @SignpostedUpdate(signposter: signposter)
            func update(world: inout World, deltaTime: Float) {}
            """,
            expandedSource: """
            func update(world: inout World, deltaTime: Float) {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@SignpostedUpdate requires update to be declared inside a type", line: 1, column: 1),
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
