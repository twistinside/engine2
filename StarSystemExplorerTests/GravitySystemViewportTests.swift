import CoreGraphics
import Testing

@testable import StarSystemExplorer

@MainActor
struct GravitySystemViewportTests {
    @Test func defaultZoomFitsExtentAndMapsPositiveYUpward() {
        let viewport = GravitySystemViewport(
            size: CGSize(width: 200, height: 100),
            padding: 10,
            extentMeters: 100
        )

        #expect(viewport.center == CGPoint(x: 100, y: 50))
        #expect(viewport.zoomScale == 1)
        #expect(viewport.pointsPerMeter == 0.4)
        #expect(viewport.visibleHorizontalHalfSpanMeters == 250)
        #expect(viewport.visibleVerticalHalfSpanMeters == 125)
        #expect(
            viewport.point(for: PlanarPosition(meters: SIMD2<Double>(100, 0)))
                == CGPoint(x: 140, y: 50)
        )
        #expect(
            viewport.point(for: PlanarPosition(meters: SIMD2<Double>(0, 100)))
                == CGPoint(x: 100, y: 10)
        )
    }

    @Test func zoomMagnifiesAroundCenterWithoutChangingOrientation() {
        let viewport = GravitySystemViewport(
            size: CGSize(width: 200, height: 100),
            padding: 10,
            extentMeters: 100,
            zoomScale: 2
        )

        #expect(viewport.center == CGPoint(x: 100, y: 50))
        #expect(viewport.zoomScale == 2)
        #expect(viewport.pointsPerMeter == 0.8)
        #expect(viewport.visibleHorizontalHalfSpanMeters == 125)
        #expect(viewport.visibleVerticalHalfSpanMeters == 62.5)
        #expect(
            viewport.point(for: PlanarPosition(meters: SIMD2<Double>(0, 0)))
                == CGPoint(x: 100, y: 50)
        )
        #expect(
            viewport.point(for: PlanarPosition(meters: SIMD2<Double>(50, 50)))
                == CGPoint(x: 140, y: 10)
        )
    }

    @Test func zoomClampsToSupportedRange() {
        let zoomedOutViewport = GravitySystemViewport(
            size: CGSize(width: 200, height: 100),
            padding: 10,
            extentMeters: 100,
            zoomScale: 0
        )
        let zoomedInViewport = GravitySystemViewport(
            size: CGSize(width: 200, height: 100),
            padding: 10,
            extentMeters: 100,
            zoomScale: 100
        )

        #expect(
            zoomedOutViewport.zoomScale
                == GravitySystemViewport.supportedZoomScaleRange.lowerBound
        )
        #expect(zoomedOutViewport.pointsPerMeter == 0.1)
        #expect(
            zoomedInViewport.zoomScale
                == GravitySystemViewport.supportedZoomScaleRange.upperBound
        )
        #expect(zoomedInViewport.pointsPerMeter == 3.2)
    }

    @Test func containsOnlyPositionsMappedInsideTheCanvas() {
        let viewport = GravitySystemViewport(
            size: CGSize(width: 200, height: 100),
            padding: 10,
            extentMeters: 100,
            zoomScale: 2
        )

        #expect(viewport.contains(PlanarPosition(meters: SIMD2<Double>(50, 50))))
        #expect(!viewport.contains(PlanarPosition(meters: SIMD2<Double>(200, 0))))
        #expect(!viewport.contains(PlanarPosition(meters: SIMD2<Double>(0, 100))))
    }
}
