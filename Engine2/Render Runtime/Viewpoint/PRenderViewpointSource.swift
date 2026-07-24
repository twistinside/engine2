/// Resolves the presentation-owned viewpoint for a render output.
///
/// The supplied camera is the publisher-authored default. A source may return
/// that camera unchanged or replace it with an independently controlled view.
@MainActor
protocol PRenderViewpointSource: AnyObject {
    func resolveViewpoint(defaultCamera: Camera) -> RenderViewpoint
}
