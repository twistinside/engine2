import SwiftUI

/// Draws epoch-invariant planet and transfer rails for one fitted system viewport.
///
/// The equatable boundary keeps playback updates from rebuilding these paths.
/// Selecting another transfer or changing the viewport still redraws the layer.
struct GravitySystemStaticRailLayer: View, Equatable {
    let viewport: GravitySystemViewport
    let planetRails: [[PlanarPosition]]
    let transferPositions: [PlanarPosition]

    var body: some View {
        Canvas { context, _ in
            drawAxes(in: &context)
            drawPlanetRails(in: &context)
            drawTransferRail(in: &context)
        }
        .accessibilityHidden(true)
    }

    private func drawAxes(in context: inout GraphicsContext) {
        var horizontalAxis = Path()
        horizontalAxis.move(to: CGPoint(x: viewport.padding, y: viewport.center.y))
        horizontalAxis.addLine(
            to: CGPoint(x: viewport.size.width - viewport.padding, y: viewport.center.y)
        )
        context.stroke(horizontalAxis, with: .color(.white.opacity(0.08)), lineWidth: 1)

        var verticalAxis = Path()
        verticalAxis.move(to: CGPoint(x: viewport.center.x, y: viewport.padding))
        verticalAxis.addLine(
            to: CGPoint(x: viewport.center.x, y: viewport.size.height - viewport.padding)
        )
        context.stroke(verticalAxis, with: .color(.white.opacity(0.08)), lineWidth: 1)
    }

    private func drawPlanetRails(in context: inout GraphicsContext) {
        for positions in planetRails {
            context.stroke(
                path(for: positions),
                with: .color(.white.opacity(0.24)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawTransferRail(in context: inout GraphicsContext) {
        guard !transferPositions.isEmpty else {
            return
        }
        context.stroke(
            path(for: transferPositions),
            with: .color(.mint),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [9, 5])
        )
        drawTransferMarker(
            transferPositions.first,
            label: "Departure",
            color: .cyan,
            in: &context
        )
        drawTransferMarker(
            transferPositions.last,
            label: "Arrival",
            color: .orange,
            in: &context
        )
    }

    private func path(for positions: [PlanarPosition]) -> Path {
        var path = Path()
        for (index, position) in positions.enumerated() {
            let point = viewport.point(for: position)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func drawTransferMarker(
        _ position: PlanarPosition?,
        label: String,
        color: Color,
        in context: inout GraphicsContext
    ) {
        guard let position else {
            return
        }
        let point = viewport.point(for: position)
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)),
            with: .color(color)
        )
        context.draw(
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color),
            at: CGPoint(x: point.x + 7, y: point.y - 7),
            anchor: .bottomLeading
        )
    }
}
