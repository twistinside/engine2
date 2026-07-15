//
//  AppDebugOptionsTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

import Testing
@testable import Engine2

struct AppDebugOptionsTests {
    @Test func inputHistoryIsVisibleByDefault() {
        #expect(AppDebugOptions().showsInputHistory)
    }
}
