import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// A photo or video picked from the Photos library. The system picker runs outside Spolo and hands over
/// only what was picked, so no library access is needed; the file is copied into Spolo's container.
struct PickedFile: Transferable {
    let url: URL

    // The still comes first, so a Live Photo arrives as its photo.
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { try PickedFile(keeping: $0.file) }
        FileRepresentation(importedContentType: .movie) { try PickedFile(keeping: $0.file) }
    }

    init(keeping file: URL) throws {
        let folder = Project.importsFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent(file.lastPathComponent)
        try FileManager.default.copyItem(at: file, to: url)
    }
}

extension Project {
    /// Copies the picked items in, in the order they were picked.
    func importFromPhotos(_ items: [PhotosPickerItem]) async {
        var urls: [URL] = []
        for item in items {
            if let file = try? await item.loadTransferable(type: PickedFile.self) {
                urls.append(file.url)
            }
        }
        if !urls.isEmpty { addImported(urls) }
    }
}
