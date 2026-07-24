import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// File-export value containing one detached JPEG artifact.
///
/// The document copies encoded bytes only. It does not retain a Runtime, GPU
/// resource, Simulation snapshot, or mutable encoder storage.
nonisolated struct JPEGArtifactDocument: FileDocument, Equatable, Sendable {
    static let readableContentTypes: [UTType] = [.jpeg]

    let encodedData: Data

    /// Creates an export document from a completed artifact.
    init(artifact: RenderedImageArtifact) {
        precondition(
            artifact.format == .jpeg,
            "JPEGArtifactDocument requires a JPEG artifact."
        )
        self.encodedData = artifact.encodedData
    }

    /// Reconstructs a JPEG document from a file selected by the user.
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.encodedData = data
    }

    /// Supplies the exact detached JPEG bytes to SwiftUI's file exporter.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        makeFileWrapper()
    }

    /// Builds the value supplied to SwiftUI's non-constructible write context.
    ///
    /// Keeping this tiny seam internal allows exact-byte testing without
    /// inventing a destination URL or writing outside the file exporter.
    func makeFileWrapper() -> FileWrapper {
        FileWrapper(regularFileWithContents: encodedData)
    }
}
