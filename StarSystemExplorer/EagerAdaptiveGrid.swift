import SwiftUI

/// Eagerly arranges all children in responsive columns with a shared minimum width.
struct EagerAdaptiveGrid: Layout {
    let minimumColumnWidth: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(minimumColumnWidth: CGFloat, horizontalSpacing: CGFloat, verticalSpacing: CGFloat) {
        precondition(
            minimumColumnWidth.isFinite && minimumColumnWidth > 0,
            "An eager adaptive grid requires a finite, positive minimum column width."
        )
        precondition(
            horizontalSpacing.isFinite && horizontalSpacing >= 0 && verticalSpacing.isFinite && verticalSpacing >= 0,
            "An eager adaptive grid requires finite, nonnegative spacing."
        )
        self.minimumColumnWidth = minimumColumnWidth
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else {
            return .zero
        }

        let availableWidth = resolvedWidth(for: proposal)
        let columnCount = columnCount(for: availableWidth, itemCount: subviews.count)
        let columnWidth = columnWidth(for: availableWidth, columnCount: columnCount)
        let rowHeights = rowHeights(for: subviews, columnWidth: columnWidth, columnCount: columnCount)
        let totalVerticalSpacing = verticalSpacing * CGFloat(max(0, rowHeights.count - 1))
        return CGSize(width: availableWidth, height: rowHeights.reduce(0, +) + totalVerticalSpacing)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else {
            return
        }

        let columnCount = columnCount(for: bounds.width, itemCount: subviews.count)
        let columnWidth = columnWidth(for: bounds.width, columnCount: columnCount)
        let rowHeights = rowHeights(for: subviews, columnWidth: columnWidth, columnCount: columnCount)
        var rowOriginY = bounds.minY

        for index in subviews.indices {
            let row = index / columnCount
            let column = index % columnCount
            if column == 0, row > 0 {
                rowOriginY += rowHeights[row - 1] + verticalSpacing
            }

            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(column) * (columnWidth + horizontalSpacing),
                    y: rowOriginY
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: columnWidth, height: rowHeights[row])
            )
        }
    }

    func columnCount(for availableWidth: CGFloat, itemCount: Int) -> Int {
        guard itemCount > 0 else {
            return 0
        }

        let fittingCount = Int((availableWidth + horizontalSpacing) / (minimumColumnWidth + horizontalSpacing))
        return min(itemCount, max(1, fittingCount))
    }

    private func resolvedWidth(for proposal: ProposedViewSize) -> CGFloat {
        guard let proposedWidth = proposal.width, proposedWidth.isFinite else {
            return minimumColumnWidth
        }
        return max(0, proposedWidth)
    }

    private func columnWidth(for availableWidth: CGFloat, columnCount: Int) -> CGFloat {
        let totalHorizontalSpacing = horizontalSpacing * CGFloat(max(0, columnCount - 1))
        return max(0, (availableWidth - totalHorizontalSpacing) / CGFloat(columnCount))
    }

    private func rowHeights(for subviews: Subviews, columnWidth: CGFloat, columnCount: Int) -> [CGFloat] {
        var heights = Array(repeating: CGFloat.zero, count: (subviews.count + columnCount - 1) / columnCount)
        let proposal = ProposedViewSize(width: columnWidth, height: nil)

        for index in subviews.indices {
            let row = index / columnCount
            heights[row] = max(heights[row], subviews[index].sizeThatFits(proposal).height)
        }
        return heights
    }
}
