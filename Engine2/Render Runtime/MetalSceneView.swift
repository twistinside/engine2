//
//  MetalSceneView.swift
//  Engine2
//
//  Created by Codex on 5/25/26.
//

import Metal
import MetalKit
import SwiftUI

@MainActor
struct MetalSceneView: NSViewRepresentable {
    var renderAssetCatalog: RenderAssetCatalog
    var presentationSource: any PSimulationPresentationSource
    var inputSink: any PInputEventSink

    func makeCoordinator() -> Coordinator {
        Coordinator(
            renderAssetCatalog: renderAssetCatalog,
            presentationSource: presentationSource
        )
    }

    func makeNSView(context: Context) -> InputMetalView {
        let view = InputMetalView(frame: .zero, device: context.coordinator.renderer?.device)

        view.autoResizeDrawable = true
        view.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
        view.colorPixelFormat = MetalRenderer.colorPixelFormat
        view.depthStencilPixelFormat = .invalid
        view.enableSetNeedsDisplay = false
        view.framebufferOnly = true
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        view.sampleCount = 1

        view.delegate = context.coordinator.renderer
        view.inputSink = inputSink
        context.coordinator.renderer?.configure(view)

        return view
    }

    func updateNSView(_ nsView: InputMetalView, context: Context) {
        context.coordinator.renderer?.presentationSource = presentationSource
        nsView.inputSink = inputSink
    }

    static func dismantleNSView(_ nsView: InputMetalView, coordinator: Coordinator) {
        nsView.inputSink = nil
        nsView.delegate = nil
    }

    @MainActor
    final class Coordinator {
        var renderer: MetalRenderer?

        init(
            renderAssetCatalog: RenderAssetCatalog,
            presentationSource: any PSimulationPresentationSource
        ) {
            self.renderer = nil

            // Construct one device-scoped store before the view begins drawing.
            // It eagerly compiles required pipelines, resolves Game Content
            // assets, and commits the static/frame residency sets.
            guard let resources = try? MetalResourceStore(
                renderAssetCatalog: renderAssetCatalog
            )
            else {
                return
            }

            renderer = try? MetalRenderer(
                resources: resources,
                presentationSource: presentationSource
            )
        }
    }
}
