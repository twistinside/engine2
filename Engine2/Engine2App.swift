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
    @State private var gameLoop: GameLoop

    private let game: Game

    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        let game = Game()
        self.game = game
        _gameLoop = State(initialValue: GameLoop(engine: game.engine))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if isRunningTests {
                gameLoop.stop()
                return
            }

            // Keep the highest-level engine driver tied to app activity rather
            // than any individual view's lifecycle.
            switch newPhase {
            case .active:
                gameLoop.start()
            case .inactive, .background:
                gameLoop.stop()
            @unknown default:
                gameLoop.stop()
            }
        }
    }
}
