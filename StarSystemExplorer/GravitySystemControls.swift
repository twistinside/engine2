import SwiftUI

/// Hosts displayed-epoch playback and transfer selection without mutating generated gravity facts.
struct GravitySystemControls: View {
    let model: GravitySystemExplorerModel

    @State private var playback = GravitySystemPlayback()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GravitySystemEpochControls(
                model: model,
                playback: $playback
            )
            Divider()
            GravitySystemTransferControls(
                model: model,
                playback: $playback
            )
        }
    }
}
