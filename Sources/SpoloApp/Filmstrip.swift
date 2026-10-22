import SwiftUI
import UniformTypeIdentifiers

/// The clips in order. Click to select (⌘ and ⇧ as in Finder), drag to reorder.
struct Filmstrip: View {
    @Bindable var project: Project
    let onSelect: (UUID) -> Void
    @State private var dragged: UUID?
    private static let end = "end"

    var body: some View {
        // The inspector floats over the trailing edge; keep the last clips reachable beside it.
        GeometryReader { geometry in
            ScrollViewReader { scroller in
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        LazyHStack(alignment: .top, spacing: 8) {
                            ForEach(project.clips) { clip in
                                ClipTile(project: project, clip: clip, selected: project.selection.contains(clip.id))
                                    .id(clip.id)
                                    .onTapGesture {
                                        project.click(clip.id)
                                        onSelect(clip.id)
                                    }
                                    .onDrag {
                                        // A drag that ended outside any clip never reached performDrop; settle it first.
                                        project.endGesture("Move Clip")
                                        dragged = clip.id
                                        project.beginGesture()
                                        return NSItemProvider(object: clip.id.uuidString as NSString)
                                    }
                                    .onDrop(of: [.plainText], delegate: Reorder(project: project, target: clip.id, dragged: $dragged))
                                    .contextMenu {
                                        // Like Finder: the menu acts on the selection if the clip is in it, otherwise on the clip.
                                        let ids = project.selection.contains(clip.id) ? project.selection : [clip.id]
                                        Button("Show in Finder") {
                                            NSWorkspace.shared.activateFileViewerSelecting(
                                                project.clips.filter { ids.contains($0.id) }.map(\.url))
                                        }
                                        Divider()
                                        Button("Remove") { project.remove(ids) }
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        // Room to scroll the last clip out from under the inspector.
                        Color.clear.frame(width: geometry.safeAreaInsets.trailing, height: 1).id(Self.end)
                    }
                }
                .onChange(of: project.clips.last?.id) { _, last in
                    if last != nil { withAnimation { scroller.scrollTo(Self.end, anchor: .trailing) } }
                }
            }
        }
        .frame(height: 124)
        .background(.background)
        .contentShape(Rectangle())
        .onTapGesture { project.selection = [] }
    }
}

/// Moves the dragged clip as it passes over others; the whole drag is one undo step.
private struct Reorder: DropDelegate {
    let project: Project
    let target: UUID
    @Binding var dragged: UUID?

    func validateDrop(info: DropInfo) -> Bool { dragged != nil }

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != target else { return }
        withAnimation(.snappy(duration: 0.2)) { project.move(dragged, before: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        project.endGesture("Move Clip")
        return true
    }
}

private struct ClipTile: View {
    let project: Project
    let clip: Clip
    let selected: Bool

    private var info: MediaInfo? { project.info[clip.id] }
    private var unavailable: Bool { info.map { !$0.isUsable } ?? false }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Rectangle().fill(.quaternary)
                if let image = project.thumbnail(clip) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if info == nil {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: info?.kind == .missing ? "questionmark.square.dashed" : "film")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 128, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .bottomTrailing) { badge }
            .overlay(alignment: .topLeading) { marks }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
            }
            Text(clip.url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(selected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 128)
        }
        .opacity(unavailable ? 0.45 : 1)
        .help(help)
        .contentShape(Rectangle())
    }

    private var help: Text {
        switch info?.kind {
        case .unsupported: Text("This format isn’t supported yet")
        case .missing: Text("The file can’t be found")
        default: Text(verbatim: clip.url.lastPathComponent)
        }
    }

    @ViewBuilder private var badge: some View {
        if let info, info.isUsable {
            Text(verbatim: TimeText.short(Segment(url: clip.url, info: info, edits: clip.edits).duration))
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(4)
        }
    }

    @ViewBuilder private var marks: some View {
        if info?.kind == .video, clip.edits.muted || clip.edits.speed != 1 {
            HStack(spacing: 3) {
                if clip.edits.speed != 1 {
                    Text(verbatim: "\(TimeText.seconds(clip.edits.speed))×")
                }
                if clip.edits.muted {
                    Image(systemName: "speaker.slash.fill")
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(4)
        }
    }
}
