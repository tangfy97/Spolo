import AppKit
import Observation

/// A file in the filmstrip. What the file turned out to be lives in `Project.info`, so undo never brings back stale details.
struct Clip: Identifiable, Equatable, Codable {
    let id: UUID
    var url: URL
    /// App-scope bookmark, so the clip is still there the next time Spolo opens.
    var bookmark: Data?
    var edits = ClipEdits()
    /// Position in the order the clips were added.
    var added: Int
    /// Copied in from Photos, into Spolo's own container.
    var imported = false
}

enum SortOrder: CaseIterable {
    case added, dateTaken, name
}

/// Everything in the window: the clips in order, how each is edited, and the frame shape.
/// Every change goes through `change`, which registers it with the window's undo manager.
@MainActor @Observable
final class Project {
    private(set) var clips: [Clip] = [] { didSet { scheduleSave() } }
    private(set) var layout = Layout() { didSet { scheduleSave() } }
    private(set) var info: [UUID: MediaInfo] = [:]
    private var thumbnails: [UUID: CGImage] = [:]
    @ObservationIgnored private var turnedThumbnails: [String: CGImage] = [:]
    var selection: Set<UUID> = []

    var showPhotosPicker = false
    var showExport = false
    @ObservationIgnored weak var undoManager: UndoManager?
    @ObservationIgnored private var nextAdded = 0
    @ObservationIgnored private var anchor: UUID?
    @ObservationIgnored private var gestureStart: Snapshot?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var restoring = false

    init() {
        restore()
    }

    // MARK: Reading

    func segment(_ clip: Clip) -> Segment? {
        info[clip.id].map { Segment(url: clip.url, info: $0, edits: clip.edits) }
    }

    /// The clips that go into the merge, in order, with their ids.
    var usable: [(id: UUID, segment: Segment)] {
        clips.compactMap { clip in segment(clip).flatMap { $0.info.isUsable ? (clip.id, $0) : nil } }
    }

    var duration: Double { usable.reduce(0) { $0 + $1.segment.duration } }
    var selectedClips: [Clip] { clips.filter { selection.contains($0.id) } }
    var canExport: Bool { !usable.isEmpty }

    func thumbnail(_ clip: Clip) -> CGImage? {
        guard let image = thumbnails[clip.id] else { return nil }
        let turns = ((clip.edits.quarterTurns % 4) + 4) % 4
        guard turns != 0 else { return image }
        let key = "\(clip.id)-\(turns)"
        if let turned = turnedThumbnails[key] { return turned }
        let turned = Thumbnail.rotate(image, quarterTurns: turns)
        turnedThumbnails[key] = turned
        return turned
    }

    // MARK: Undo

    private struct Snapshot: Equatable {
        var clips: [Clip]
        var layout: Layout
    }

    private var snapshot: Snapshot { Snapshot(clips: clips, layout: layout) }

    private func apply(_ snapshot: Snapshot) {
        clips = snapshot.clips
        layout = snapshot.layout
        selection.formIntersection(clips.map(\.id))
    }

    /// Makes a change that Edit ▸ Undo can take back.
    func change(_ name: String.LocalizationValue, _ body: () -> Void) {
        let before = snapshot
        body()
        registerUndo(from: before, name: name)
    }

    private func registerUndo(from before: Snapshot, name: String.LocalizationValue) {
        let after = snapshot
        guard before != after, let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { project in
            project.apply(before)
            project.registerUndo(from: after, name: name)
        }
        undoManager.setActionName(String(localized: name))
    }

    /// For sliders: the whole drag becomes one undo step.
    func beginGesture() {
        if gestureStart == nil { gestureStart = snapshot }
    }

    func endGesture(_ name: String.LocalizationValue) {
        guard let before = gestureStart else { return }
        gestureStart = nil
        registerUndo(from: before, name: name)
    }

    // MARK: Changes

    func add(_ urls: [URL]) {
        let files = Self.expand(urls)
        guard !files.isEmpty else { return }
        var added: [Clip] = []
        for url in files {
            let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            added.append(Clip(id: UUID(), url: url, bookmark: bookmark, edits: Self.newEdits, added: nextAdded))
            nextAdded += 1
        }
        change("Add Clips") { clips += added }
        selection = Set(added.map(\.id))
        anchor = added.last?.id
        read(added)
    }

    func addImported(_ urls: [URL]) {
        var added: [Clip] = []
        for url in urls {
            added.append(Clip(id: UUID(), url: url, bookmark: nil, edits: Self.newEdits, added: nextAdded, imported: true))
            nextAdded += 1
        }
        change("Add Clips") { clips += added }
        selection = Set(added.map(\.id))
        read(added)
    }

    /// Edits a newly added clip starts with: the photo duration from Settings.
    private static var newEdits: ClipEdits {
        var edits = ClipEdits()
        edits.photoDuration = Preference.defaultPhotoDuration
        return edits
    }

    func removeSelection() { remove(selection) }

    func remove(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        change("Remove") { clips.removeAll { ids.contains($0.id) } }
        selection.subtract(ids)
    }

    func move(_ id: UUID, before target: UUID) {
        guard id != target, let from = clips.firstIndex(where: { $0.id == id }),
              let to = clips.firstIndex(where: { $0.id == target }) else { return }
        clips.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func sort(_ order: SortOrder) {
        change("Sort") {
            switch order {
            case .added:
                clips.sort { $0.added < $1.added }
            case .name:
                clips.sort {
                    let order = $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent)
                    return order == .orderedSame ? $0.added < $1.added : order == .orderedAscending
                }
            case .dateTaken:
                clips.sort {
                    switch (info[$0.id]?.dateTaken, info[$1.id]?.dateTaken) {
                    case let (a?, b?) where a != b: a < b
                    case (_?, nil): true
                    case (nil, _?): false
                    default: $0.added < $1.added
                    }
                }
            }
        }
    }

    func setLayout(_ name: String.LocalizationValue, _ body: (inout Layout) -> Void) {
        change(name) { body(&layout) }
    }

    /// Changes the edits of every selected clip, or of `ids`. Without `undoName` the change is part of a gesture.
    func edit(_ undoName: String.LocalizationValue?, ids: Set<UUID>? = nil, _ body: (inout ClipEdits, MediaInfo) -> Void) {
        let targets = ids ?? selection
        withoutActuallyEscaping(body) { body in
            let apply = {
                for index in self.clips.indices where targets.contains(self.clips[index].id) {
                    guard let info = self.info[self.clips[index].id] else { continue }
                    body(&self.clips[index].edits, info)
                }
            }
            if let undoName { change(undoName, apply) } else { apply() }
        }
    }

    func rotateSelection(by turns: Int) {
        edit("Rotate") { edits, _ in edits.quarterTurns = (edits.quarterTurns + turns + 4) % 4 }
    }

    // MARK: Selection

    /// Click, ⌘-click and ⇧-click, as in Finder.
    func click(_ id: UUID) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
            anchor = id
        } else if flags.contains(.shift), let anchor, let a = clips.firstIndex(where: { $0.id == anchor }),
                  let b = clips.firstIndex(where: { $0.id == id }) {
            selection = Set(clips[min(a, b)...max(a, b)].map(\.id))
        } else {
            selection = [id]
            anchor = id
        }
    }

    func selectAll() { selection = Set(clips.map(\.id)) }

    // MARK: Reading files

    /// Files as they were dropped or chosen: folders are opened, and only photos and videos are kept.
    static func expand(_ urls: [URL]) -> [URL] {
        urls.flatMap { url -> [URL] in
            var isFolder: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) else { return [] }
            guard isFolder.boolValue else { return MediaProbe.isMedia(url) ? [url] : [] }
            let items = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                                       options: [.skipsHiddenFiles, .skipsPackageDescendants])
            return (items?.compactMap { $0 as? URL } ?? [])
                .filter(MediaProbe.isMedia)
                .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        }
    }

    private func read(_ new: [Clip]) {
        for clip in new {
            Task {
                let info = await MediaProbe.probe(clip.url)
                self.info[clip.id] = info
                if let image = await Thumbnail.make(clip.url, kind: info.kind) {
                    self.thumbnails[clip.id] = image
                }
            }
        }
    }

    // MARK: Saving

    private struct Saved: Codable {
        var clips: [Clip]
        var layout: Layout
        var nextAdded: Int
    }

    nonisolated private static var folder: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Spolo", isDirectory: true)
    }

    nonisolated private static var sessionFile: URL { folder.appendingPathComponent("Session.json") }

    /// Where photos and videos picked from the Photos library are kept, since they have no file of their own.
    nonisolated static var importsFolder: URL { folder.appendingPathComponent("Imports", isDirectory: true) }

    private func scheduleSave() {
        guard !restoring else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    func save() {
        let saved = Saved(clips: clips, layout: layout, nextAdded: nextAdded)
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        try? JSONEncoder().encode(saved).write(to: Self.sessionFile, options: .atomic)
    }

    /// Brings back the last session's clips through their bookmarks, and clears out imports no clip uses.
    private func restore() {
        restoring = true
        defer { restoring = false }
        guard UserDefaults.standard.bool(forKey: Preference.reopenClips),
              let data = try? Data(contentsOf: Self.sessionFile),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else {
            cleanImports()
            return
        }
        layout = saved.layout
        nextAdded = saved.nextAdded
        clips = saved.clips.map { clip in
            var clip = clip
            if let bookmark = clip.bookmark {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale) {
                    _ = url.startAccessingSecurityScopedResource()
                    clip.url = url
                    if stale {
                        clip.bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    }
                }
            } else if clip.imported {
                clip.url = Self.importsFolder.appendingPathComponent(clip.url.pathComponents.suffix(2).joined(separator: "/"))
            }
            return clip
        }
        cleanImports()
        read(clips)
    }

    private func cleanImports() {
        let kept = Set(clips.filter(\.imported).map { $0.url.deletingLastPathComponent().lastPathComponent })
        let folders = (try? FileManager.default.contentsOfDirectory(at: Self.importsFolder, includingPropertiesForKeys: nil)) ?? []
        for folder in folders where !kept.contains(folder.lastPathComponent) {
            try? FileManager.default.removeItem(at: folder)
        }
    }
}
