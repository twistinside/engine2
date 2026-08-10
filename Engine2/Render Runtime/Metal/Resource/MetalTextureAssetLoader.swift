import Foundation
import Metal
import MetalKit

/// Decodes one backend-neutral packaged texture into immutable Metal storage.
///
/// Game Content resolves the exact file URL and declares whether texels are
/// authored color or linear data. Render owns decoding, mip generation, GPU
/// usage, storage mode, labels, and the resulting device allocation.
struct MetalTextureAssetLoader {
    private let loader: MTKTextureLoader

    init(device: any MTLDevice) {
        self.loader = MTKTextureLoader(device: device)
    }

    /// Loads one texture once during resource-store construction.
    func load(_ reference: TextureAssetReference) throws -> any MTLTexture {
        guard FileManager.default.fileExists(
            atPath: reference.resourceURL.path
        ) else {
            throw MetalRendererError.missingTexture(reference)
        }

        let options: [MTKTextureLoader.Option: Any] = [
            .SRGB: reference.interpretation == .sRGB,
            .generateMipmaps: true,
            .textureUsage: NSNumber(
                value: MTLTextureUsage.shaderRead.rawValue
            ),
            .textureStorageMode: NSNumber(
                value: MTLStorageMode.private.rawValue
            )
        ]
        let texture = try loader.newTexture(
            URL: reference.resourceURL,
            options: options
        )
        texture.label = reference.resourceURL.lastPathComponent
        return texture
    }
}
