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
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.renderer?.device)

        view.autoResizeDrawable = true
        view.clearColor = MTLClearColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1)
        view.colorPixelFormat = MetalRenderer.colorPixelFormat
        view.depthStencilPixelFormat = .invalid
        view.enableSetNeedsDisplay = false
        view.framebufferOnly = true
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        view.sampleCount = 1

        view.delegate = context.coordinator.renderer
        context.coordinator.renderer?.configure(view)

        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    @MainActor
    final class Coordinator {
        let renderer: MetalRenderer?

        init() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeMTL4CommandQueue(),
                  let renderPipelineState = try? MetalRenderer.makeRenderPipelineState(device: device)
            else {
                renderer = nil
                return
            }

            var commandAllocators: [any MTL4CommandAllocator] = []

            for _ in 0..<MetalRenderer.maximumFramesInFlight {
                guard let commandAllocator = device.makeCommandAllocator() else {
                    renderer = nil
                    return
                }

                commandAllocators.append(commandAllocator)
            }

            renderer = MetalRenderer(
                device: device,
                renderPipelineState: renderPipelineState,
                commandQueue: commandQueue,
                commandAllocators: commandAllocators
            )
        }
    }
}
