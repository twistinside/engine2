//
//  Engine2App.swift
//  Engine2
//
//  Created by Karl Groff on 3/8/26.
//

import SwiftUI

@main
struct Engine2App: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var game: Game

    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        _game = State(initialValue: Game())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(game: game)
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if isRunningTests {
                game.stop()
                return
            }

            // Keep the highest-level engine driver tied to app activity rather
            // than any individual view's lifecycle.
            switch newPhase {
            case .active:
                game.start()
            case .inactive, .background:
                game.stop()
            @unknown default:
                game.stop()
            }
        }
    }
}
