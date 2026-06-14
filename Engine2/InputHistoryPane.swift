//
//  InputHistoryPane.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

import SwiftUI

@MainActor
struct InputHistoryPane: View {
    let game: Game

    var body: some View {
        TimelineView(.animation) { _ in
            let entries = game.world.input.history

            GlassEffectContainer(spacing: 8) {
                VStack(alignment: .leading, spacing: 10) {
                    InputHistoryHeader(entryCount: entries.count)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(entries) { entry in
                                InputHistoryRow(entry: entry)
                            }
                        }
                    }
                    .frame(maxHeight: 460)
                }
                .padding(14)
                .frame(width: 320, alignment: .leading)
                .glassEffect(
                    .regular.tint(.cyan.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Input history")
        }
    }
}
