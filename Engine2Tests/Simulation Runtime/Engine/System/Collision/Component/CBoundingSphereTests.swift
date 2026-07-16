//
//  CBoundingSphereTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

import Testing
@testable import Engine2

struct CBoundingSphereTests {
    @Test func storesPositiveCollisionRadius() {
        let sphere = CBoundingSphere(radius: 2.5)

        #expect(sphere.radius == 2.5)
    }
}
