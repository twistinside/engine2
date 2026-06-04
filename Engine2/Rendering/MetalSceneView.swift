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
    var renderFrameProvider: @MainActor () -> RenderFrame

    func makeCoordinator() -> Coordinator {
        Coordinator(renderFrameProvider: renderFrameProvider)
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

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.renderFrameProvider = renderFrameProvider
    }

    @MainActor
    final class Coordinator {
        var renderFrameProvider: @MainActor () -> RenderFrame
        var renderer: MetalRenderer?

        init(renderFrameProvider: @escaping @MainActor () -> RenderFrame) {
            self.renderFrameProvider = renderFrameProvider
            self.renderer = nil

            guard let device = MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeMTL4CommandQueue(),
                  let renderPipelineState = try? MetalRenderer.makeRenderPipelineState(device: device),
                  let argumentTable = try? MetalRenderer.makeArgumentTable(device: device),
                  let triangle = try? USDRenderModel.load(named: "PrettyTriangle", device: device),
                  let frameResources = try? MetalRenderer.makeFrameResources(device: device)
            else {
                return
            }

            renderer = MetalRenderer(
                device: device,
                renderPipelineState: renderPipelineState,
                argumentTable: argumentTable,
                model: triangle,
                renderFrameProvider: { [weak self] in
                    self?.renderFrameProvider() ?? .empty
                },
                frameResidencySet: frameResources.residencySet,
                commandQueue: commandQueue,
                frames: frameResources.frames
            )
        }
    }
}
