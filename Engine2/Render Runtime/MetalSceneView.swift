import Metal
import MetalKit
import SwiftUI

/// SwiftUI bridge that hosts the Render Runtime's MetalKit view and renderer.
///
/// The bridge wires a read-only simulation presentation source to a
/// coordinator-owned `MetalRenderer` and an input sink to the platform view.
/// Rendering therefore samples completed snapshots instead of reading live
/// `World` state or directly calling the Simulation Runtime.
@MainActor
struct MetalSceneView: NSViewRepresentable {
    var renderAssetCatalog: RenderAssetCatalog
    var presentationSource: any PSimulationPresentationSource
    var inputSink: any PInputEventSink
    var outputMode: RenderOutputMode

    func makeCoordinator() -> Coordinator {
        Coordinator(
            renderAssetCatalog: renderAssetCatalog,
            presentationSource: presentationSource,
            outputMode: outputMode
        )
    }

    func makeNSView(context: Context) -> InputMetalView {
        let view = InputMetalView(frame: .zero, device: context.coordinator.renderer?.device)

        view.autoResizeDrawable = true
        view.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
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
        context.coordinator.renderer?.outputMode = outputMode
        nsView.inputSink = inputSink
    }

    static func dismantleNSView(_ nsView: InputMetalView, coordinator: Coordinator) {
        nsView.inputSink = nil
        nsView.delegate = nil
    }

    /// Owns the renderer for the lifetime of one SwiftUI representable view.
    ///
    /// Initialization may leave `renderer` unavailable when the current device
    /// cannot construct the required Metal resources; the host view remains
    /// safe to create and simply submits no render work.
    @MainActor
    final class Coordinator {
        var renderer: MetalRenderer?

        init(
            renderAssetCatalog: RenderAssetCatalog,
            presentationSource: any PSimulationPresentationSource,
            outputMode: RenderOutputMode
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
                presentationSource: presentationSource,
                outputMode: outputMode
            )
        }
    }
}
