import Foundation
import SwiftUI

/// Emits animation timeline dates without making the controls tree timeline content.
struct GravitySystemPlaybackTimelineDriver: View {
    let isPlaying: Bool
    let updateDisplayedEpoch: (Date) -> Void

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: GravitySystemPlayback.preferredFrameIntervalSeconds,
                paused: !isPlaying
            )
        ) { context in
            Color.clear
                .frame(width: 0, height: 0)
                .onChange(of: context.date) { _, date in
                    updateDisplayedEpoch(date)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
