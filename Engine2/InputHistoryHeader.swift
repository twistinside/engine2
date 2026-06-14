//
//  InputHistoryHeader.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

import SwiftUI

struct InputHistoryHeader: View {
    let entryCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Input")
                    .font(.headline)

                Text("Fixed-step history")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entryCount, format: .number)
                .font(.title3.monospacedDigit().weight(.semibold))
                .contentTransition(.numericText())
        }
    }
}
