//
//  InputHistoryPane.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

import SwiftUI

@MainActor
struct InputHistoryPane: View {
    let simulation: SimulationRuntime

    var body: some View {
        TimelineView(.animation) { _ in
            let entries = simulation.world.input.history

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
