//
//  InputHistoryRow.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

import SwiftUI

struct InputHistoryRow: View {
    let entry: InputHistoryEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("#\(entry.frameIndex)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(entry.tokenText)
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)

            Text("x\(entry.frameCount)")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Frame \(entry.frameIndex), \(entry.tokenText), \(entry.frameCount) frames")
    }
}
