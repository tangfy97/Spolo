import SwiftUI

/// How the selected clips are handled: trim, speed and sound for videos, duration for photos, and rotation.
struct InspectorView: View {
    @Bindable var project: Project

    private var selected: [(clip: Clip, info: MediaInfo)] {
        project.selectedClips.compactMap { clip in project.info[clip.id].map { (clip, $0) } }
    }
    private var videos: [(clip: Clip, info: MediaInfo)] { selected.filter { $0.info.kind == .video } }
    private var photos: [(clip: Clip, info: MediaInfo)] { selected.filter { $0.info.kind == .photo } }

    var body: some View {
        if project.selection.isEmpty {
            Form { mergedVideo }
                .formStyle(.grouped)
        } else {
            Form {
                header
                if !videos.isEmpty { videoSection }
                if !photos.isEmpty { photoSection }
                if !videos.isEmpty || !photos.isEmpty {
                    Section {
                        LabeledContent("Rotate") {
                            ControlGroup {
                                Button { project.rotateSelection(by: -1) } label: {
                                    Label("Rotate Left", systemImage: "rotate.left")
                                }
                                Button { project.rotateSelection(by: 1) } label: {
                                    Label("Rotate Right", systemImage: "rotate.right")
                                }
                            }
                            .labelStyle(.iconOnly)
                            .fixedSize()
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    /// With no clip selected, the inspector shows the merged video as a whole.
    @ViewBuilder private var mergedVideo: some View {
        let size = Timeline.renderSize(project.usable.map(\.segment), layout: project.layout)
        Section("Merged Video") {
            Picker("Shape", selection: Binding(get: { project.layout.shape }, set: { shape in
                project.setLayout("Change Shape") { $0.shape = shape }
            })) {
                ForEach(FrameShape.allCases, id: \.self) { shape in
                    if let name = shape.ratioName { Text(verbatim: name).tag(shape) } else { Text("Auto").tag(shape) }
                }
            }
            Picker("Scale", selection: Binding(get: { project.layout.fill }, set: { fill in
                project.setLayout("Change Fill") { $0.fill = fill }
            })) {
                Text("Fit").tag(FillMode.fit)
                Text("Fill").tag(FillMode.fill)
            }
            .pickerStyle(.segmented)
        }
        Section {
            LabeledContent("Clips") { Text(verbatim: "\(project.usable.count)").monospacedDigit() }
            LabeledContent("Length") { Text(verbatim: TimeText.short(project.duration)).monospacedDigit() }
            LabeledContent("Size") { Text(verbatim: "\(Int(size.width)) × \(Int(size.height))").monospacedDigit() }
        }
    }

    @ViewBuilder private var header: some View {
        Section {
            if selected.count == 1, let (clip, info) = selected.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: clip.url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    if info.isUsable {
                        Text(verbatim: details(info))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("^[\(project.selection.count) Clip](inflect: true)")
                    .font(.headline)
            }
        }
    }

    private func details(_ info: MediaInfo) -> String {
        var parts = ["\(Int(info.size.width)) × \(Int(info.size.height))"]
        if info.kind == .video {
            parts.append(TimeText.short(info.duration))
            parts.append(info.frameRate.formatted(.number.precision(.fractionLength(0...2))) + " fps")
            if info.isHDR { parts.append("HDR") }
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Video

    @ViewBuilder private var videoSection: some View {
        Section {
            if videos.count == 1, let (clip, info) = videos.first {
                trim(clip, info)
            }
            Picker("Speed", selection: Binding(
                get: { videos.first?.clip.edits.speed ?? 1 },
                set: { speed in project.edit("Change Speed", ids: Set(videos.map(\.clip.id))) { edits, _ in edits.speed = speed } }
            )) {
                ForEach(ClipEdits.speeds, id: \.self) { speed in
                    Text(verbatim: "\(TimeText.seconds(speed))×").tag(speed)
                }
            }
            Toggle("Mute", sources: videos.map { video in
                Binding(get: { video.clip.edits.muted }, set: { muted in
                    project.edit("Mute", ids: [video.clip.id]) { edits, _ in edits.muted = muted }
                })
            }, isOn: \.self)
        } header: {
            if !photos.isEmpty { Text("Videos") }
        }
    }

    @ViewBuilder private func trim(_ clip: Clip, _ info: MediaInfo) -> some View {
        let length = info.duration
        let gap = ClipEdits.shortestClip
        let start = Binding(
            get: { clip.edits.trimStart },
            set: { value in project.edit(nil, ids: [clip.id]) { edits, _ in edits.trimStart = value } })
        let end = Binding(
            get: { length - clip.edits.trimEnd },
            set: { value in project.edit(nil, ids: [clip.id]) { edits, _ in edits.trimEnd = length - value } })
        LabeledContent("Start") {
            HStack {
                Slider(value: start, in: 0...max(gap, length - clip.edits.trimEnd - gap), onEditingChanged: gesture("Trim"))
                Text(verbatim: TimeText.precise(clip.edits.trimStart))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
        LabeledContent("End") {
            HStack {
                Slider(value: end, in: min(length - gap, clip.edits.trimStart + gap)...length, onEditingChanged: gesture("Trim"))
                Text(verbatim: TimeText.precise(length - clip.edits.trimEnd))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private func gesture(_ name: String.LocalizationValue) -> (Bool) -> Void {
        { editing in editing ? project.beginGesture() : project.endGesture(name) }
    }

    // MARK: Photo

    @ViewBuilder private var photoSection: some View {
        let ids = Set(photos.map(\.clip.id))
        let duration = photos.first?.clip.edits.photoDuration ?? 3
        Section {
            LabeledContent("Duration") {
                Stepper {
                    Text("\(TimeText.seconds(duration)) s")
                        .monospacedDigit()
                } onIncrement: {
                    set(ids, Self.step(duration, by: 1))
                } onDecrement: {
                    set(ids, Self.step(duration, by: -1))
                }
            }
        } header: {
            if !videos.isEmpty { Text("Photos") }
        }
    }

    private func set(_ ids: Set<UUID>, _ duration: Double) {
        project.edit("Change Duration", ids: ids) { edits, _ in edits.photoDuration = duration }
    }

    /// Half seconds up to 5 s, whole seconds up to 10 s, then fives, up to a minute.
    static func step(_ value: Double, by direction: Int) -> Double {
        let stops = stride(from: 0.5, through: 5, by: 0.5).map { $0 } + (6...10).map(Double.init) + stride(from: 15.0, through: 60, by: 5).map { $0 }
        if direction > 0 { return stops.first { $0 > value + 0.001 } ?? 60 }
        return stops.last { $0 < value - 0.001 } ?? 0.5
    }
}
