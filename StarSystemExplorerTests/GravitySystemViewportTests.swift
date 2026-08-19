import CoreGraphics
import Testing

@testable import StarSystemExplorer

@MainActor
struct GravitySystemViewportTests {
    @Test func viewportPreservesScaleAndMapsPositiveYUpward() {
        let viewport = GravitySystemViewport(
            size: CGSize(width: 200, height: 100),
            padding: 10,
            extentMeters: 100
        )

        #expect(viewport.center == CGPoint(x: 100, y: 50))
        #expect(viewport.pointsPerMeter == 0.4)
        #expect(
            viewport.point(for: PlanarPosition(meters: SIMD2<Double>(100, 0)))
                == CGPoint(x: 140, y: 50)
        )
        #expect(
            viewport.point(for: PlanarPosition(meters: SIMD2<Double>(0, 100)))
                == CGPoint(x: 100, y: 10)
        )
    }
}
