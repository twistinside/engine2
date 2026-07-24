import SwiftUI

/// Debug overlay that presents the Simulation Runtime's retained input history.
///
/// The timeline refreshes at presentation cadence while the displayed rows
/// remain simulation-owned facts recorded only at fixed-step boundaries. Its
/// closure is an App-wired read capability, not access to the concrete Runtime.
struct InputHistoryPane: View {
    let entries: @MainActor () -> [InputHistoryEntry]

    var body: some View {
        TimelineView(.animation) { _ in
            let entries = entries()

            GlassEffectContainer(spacing: 8) {
                VStack(alignment: .leading, spacing: 10) {
                    InputHistoryHeader(entryCount: entries.count)

                    List(entries) { entry in
                        InputHistoryRow(entry: entry)
                            .listRowBackground(Color.clear)
                            .listRowInsets(
                                EdgeInsets(
                                    top: 4,
                                    leading: 0,
                                    bottom: 4,
                                    trailing: 0
                                )
                            )
                        }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: 460)
                }
                .padding(14)
                .frame(width: 320, alignment: .leading)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Input history")
        }
    }
}
