import Metal

/// Engine2-owned render-pipeline compilation policy for one resolved shader library.
///
/// This value translates Engine2's required function names, labels, and pixel
/// formats into Metal 4 descriptors. The injected compiler remains the backend
/// that validates each descriptor and creates its pipeline state.
struct MetalRenderPipelineCompiler {
    private let compiler: any MTL4Compiler

    private let library: any MTLLibrary

    /// Binds Engine2's descriptor policy to one compiler and shader library.
    init(compiler: any MTL4Compiler, library: any MTLLibrary) {
        self.compiler = compiler
        self.library = library
    }

    /// Compiles one required render pipeline from its named shader entry points.
    func compile(
        vertexFunctionName: String,
        fragmentFunctionName: String,
        label: String,
        colorPixelFormat: MTLPixelFormat,
        blendMode: MetalRenderBlendMode = .opaque
    ) throws -> any MTLRenderPipelineState {
        let vertexFunction = MTL4LibraryFunctionDescriptor()
        vertexFunction.library = library
        vertexFunction.name = vertexFunctionName

        let fragmentFunction = MTL4LibraryFunctionDescriptor()
        fragmentFunction.library = library
        fragmentFunction.name = fragmentFunctionName

        let descriptor = MTL4RenderPipelineDescriptor()
        descriptor.label = label
        descriptor.vertexFunctionDescriptor = vertexFunction
        descriptor.fragmentFunctionDescriptor = fragmentFunction
        descriptor.rasterSampleCount = 1
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        blendMode.apply(to: descriptor.colorAttachments[0])
        return try compiler.makeRenderPipelineState(descriptor: descriptor)
    }
}
