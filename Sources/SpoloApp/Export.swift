import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Runs one export at a time and reports it at the bottom of the window.
@MainActor @Observable
final class ExportController {
    enum State {
        case idle
        case running(progress: Double, remaining: Double?)
        case done(URL)
        case failed(String)
    }

    var state = State.idle
    private var exporter: Exporter?

    var isRunning: Bool {
        if case .running = state { true } else { false }
    }

    func start(_ segments: [Segment], layout: Layout, format: ExportFormat, quality: ExportQuality, to url: URL) {
        let exporter = Exporter(segments: segments, layout: layout, format: format, quality: quality)
        self.exporter = exporter
        state = .running(progress: 0, remaining: nil)
        let started = Date()
        Task {
            do {
                try await exporter.export(to: url) { value in
                    Task { @MainActor in
                        guard self.exporter === exporter, self.isRunning else { return }
                        let elapsed = Date().timeIntervalSince(started)
                        let remaining = value > 0.05 && elapsed > 2 ? elapsed / value * (1 - value) : nil
                        self.state = .running(progress: value, remaining: remaining)
                    }
                }
                if self.exporter === exporter { state = .done(url) }
            } catch is CancellationError {
                if self.exporter === exporter { state = .idle }
            } catch {
                if self.exporter === exporter { state = .failed(error.localizedDescription) }
            }
        }
    }

    func cancel() {
        exporter?.cancel()
        exporter = nil
        state = .idle
    }

    func dismiss() {
        state = .idle
    }
}

/// Asks what to save as: format and quality, then the save panel.
struct ExportSheet: View {
    let project: Project
    let controller: ExportController
    @Environment(\.dismiss) private var dismiss
    @AppStorage("format") private var format = ExportFormat.mp4
    @AppStorage("quality") private var quality = ExportQuality.original

    private var segments: [Segment] { project.usable.map(\.segment) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Format", selection: $format) {
                        Text(verbatim: "MP4").tag(ExportFormat.mp4)
                        Text(verbatim: "MOV").tag(ExportFormat.mov)
                    }
                    .pickerStyle(.segmented)
                    Picker("Quality", selection: $quality) {
                        Text("Original").tag(ExportQuality.original)
                        Text("High").tag(ExportQuality.high)
                        Text("Smaller File").tag(ExportQuality.smaller)
                    }
                    LabeledContent("Size") {
                        Text(verbatim: size)
                            .monospacedDigit()
                    }
                } footer: {
                    if quality == .original, Timeline.canJoinWithoutReencoding(segments, layout: project.layout) {
                        Text("Fast export, no re-encoding")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Export…") {
                    dismiss()
                    choose()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 400)
        .fixedSize()
    }

    private var size: String {
        let render = Timeline.renderSize(segments, layout: project.layout,
                                         maxLongEdge: quality == .original ? nil : 1920)
        return "\(Int(render.width)) × \(Int(render.height))"
    }

    private func choose() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .mp4 ? .mpeg4Movie : .quickTimeMovie]
        panel.nameFieldStringValue = String(localized: "Merged Video") + "." + format.fileExtension
        panel.canCreateDirectories = true
        let (segments, layout, format, quality) = (segments, project.layout, format, quality)
        let finish = { (response: NSApplication.ModalResponse) in
            guard response == .OK, let url = panel.url else { return }
            controller.start(segments, layout: layout, format: format, quality: quality, to: url)
        }
        // The export sheet is still closing, so attach the panel to the window underneath it.
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.sheetParent == nil && !($0 is NSPanel) }) {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }
}

/// Progress, then the finished file, along the bottom of the window.
struct ExportBar: View {
    let controller: ExportController

    var body: some View {
        HStack(spacing: 12) {
            switch controller.state {
            case .idle:
                EmptyView()
            case .running(let progress, let remaining):
                ProgressView(value: progress)
                Group {
                    if let remaining {
                        Text("About \(TimeText.short(max(1, remaining))) remaining")
                    } else {
                        Text("Exporting…")
                    }
                }
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()
                Button("Cancel", action: controller.cancel)
            case .done(let url):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(verbatim: url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                ShareLink(item: url) {
                    Label("Share…", systemImage: "square.and.arrow.up")
                }
                closeButton
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .lineLimit(2)
                Spacer()
                closeButton
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var closeButton: some View {
        Button(action: controller.dismiss) {
            Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
        .help(Text("Close"))
    }
}
