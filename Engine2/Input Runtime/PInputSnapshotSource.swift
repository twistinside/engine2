//
//  PInputSnapshotSource.swift
//  Engine2
//
//  Created by Codex on 7/16/26.
//

/// Read-only latest-value boundary published by an Input Runtime.
@MainActor
protocol PInputSnapshotSource: AnyObject {
    var latestInputSnapshot: InputSnapshot { get }
}
