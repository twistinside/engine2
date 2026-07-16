//
//  CRenderable.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

/// Abstract presentation identity for a simulation entity.
///
/// The component names the mesh content but contains no renderer-owned model,
/// buffer, material, or other backend resource.
struct CRenderable: PComponent {
    var meshID: MeshID
}
