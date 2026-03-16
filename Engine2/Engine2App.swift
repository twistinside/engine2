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
    @State private var appEngineLoop = AppEngineLoop()

    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if isRunningTests {
                appEngineLoop.stop()
                return
            }

            // Keep the highest-level engine driver tied to app activity rather
            // than any individual view's lifecycle.
            switch newPhase {
            case .active:
                appEngineLoop.start()
            case .inactive, .background:
                appEngineLoop.stop()
            @unknown default:
                appEngineLoop.stop()
            }
        }
    }
}
