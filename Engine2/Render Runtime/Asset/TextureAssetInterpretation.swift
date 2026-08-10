/// Transfer-function interpretation applied when Render decodes a source texture.
///
/// Color assets use sRGB decoding before shader access. Data assets preserve
/// their stored channel values so height, masks, and other numeric controls do
/// not receive a color transfer function.
nonisolated enum TextureAssetInterpretation: Equatable, Hashable, Sendable {
    case sRGB
    case linear
}
