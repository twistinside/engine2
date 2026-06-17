//
//  CRotation.swift
//  Engine2
//
//  Created by Codex on 3/15/26.
//

import simd

struct CRotation: Component {
    let rotation: simd_quatf
}

extension CRotation: Codable {
    private enum CodingKeys: String, CodingKey {
        case vector
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let vector = try container.decode(SIMD4<Float>.self, forKey: .vector)
        self.rotation = simd_quatf(vector: vector)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rotation.vector, forKey: .vector)
    }
}

extension CRotation: Equatable {
    static func == (lhs: CRotation, rhs: CRotation) -> Bool {
        lhs.rotation.vector == rhs.rotation.vector
    }
}
