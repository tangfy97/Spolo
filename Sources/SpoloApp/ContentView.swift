import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var project: Project
    let exporter: ExportController
    @State private var preview = Preview()
    @State private var showInspector = true
    @State private var dropTargeted = false
    @State private var picked: [PhotosPickerItem] = []
    @Environment(\.undoManager) private var undoManager

    private var previewKey: Preview.Key {
        let usable = project.usable
        return Preview.Key(ids: usable.map(\.id), segments: usable.map(\.segment), layout: project.layout)
    }

    var body: some View {
        Group {
            if project.clips.isEmpty {
                empty
            } else {
                editor
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .navigationSubtitle(subtitle)
        .toolbar { toolbar }
        .inspector(isPresented: Binding(get: { showInspector && !project.clips.isEmpty }, set: { showInspector = $0 })) {
            InspectorView(project: project)
                .inspectorColumnWidth(min: 250, ideal: 280, max: 380)
                .toolbar {
                    ToolbarItem {
                        Button { showInspector.toggle() } label: {
                            Label("Inspector", systemImage: "sidebar.trailing")
                        }
                        .help(Text("Show or hide the inspector"))
                    }
                }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: drop)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(3)
                    .allowsHitTesting(false)
            }
        }
        .photosPicker(isPresented: $project.showPhotosPicker, selection: $picked,
                      matching: .any(of: [.images, .videos]), preferredItemEncoding: .current)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            Task { await project.importFromPhotos(items) }
        }
        .sheet(isPresented: $project.showExport) {
            ExportSheet(project: project, controller: exporter)
        }
        .task(id: previewKey) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await preview.update(previewKey)
        }
        .onAppear { project.undoManager = undoManager }
        .onChange(of: undoManager) { _, manager in project.undoManager = manager }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("Drop Photos and Videos Here", systemImage: "film.stack")
        } actions: {
            HStack {
                Button("Add…", action: project.chooseFiles)
                Button("Add from Photos…") { project.showPhotosPicker = true }
            }
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            PlayerView(player: preview.player)
                .background(.black)
            Divider()
            Filmstrip(project: project) { id in
                if project.selection == [id] { preview.show(id) }
            }
            if !(exporter.state.isIdle) {
                Divider()
                ExportBar(controller: exporter)
            }
        }
    }

    private var subtitle: Text {
        guard !project.clips.isEmpty else { return Text(verbatim: "") }
        return Text("^[\(project.clips.count) Clip](inflect: true)") + Text(verbatim: " · " + TimeText.short(project.duration))
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Menu {
                Button("Add…", action: project.chooseFiles)
                Button("Add from Photos…") { project.showPhotosPicker = true }
            } label: {
                Label("Add", systemImage: "plus")
            } primaryAction: {
                project.chooseFiles()
            }
            .help(Text("Add photos and videos"))
        }
        ToolbarItemGroup {
            Menu {
                Button("Order Added") { project.sort(.added) }
                Button("Date Taken") { project.sort(.dateTaken) }
                Button("File Name") { project.sort(.name) }
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
            }
            .help(Text("Sort the clips"))
            .disabled(project.clips.count < 2)

            Picker("Shape", selection: Binding(get: { project.layout.shape }, set: { shape in
                project.setLayout("Change Shape") { $0.shape = shape }
            })) {
                ForEach(FrameShape.allCases, id: \.self) { shape in
                    if let name = shape.ratioName { Text(verbatim: name).tag(shape) } else { Text("Auto").tag(shape) }
                }
            }
            .pickerStyle(.menu)
            .help(Text("Shape of the video"))

            Picker("Fill", selection: Binding(get: { project.layout.fill }, set: { fill in
                project.setLayout("Change Fill") { $0.fill = fill }
            })) {
                Text("Fit").tag(FillMode.fit)
                Text("Fill").tag(FillMode.fill)
            }
            .pickerStyle(.segmented)
            .help(Text("Fit with black bars, or fill and crop"))
        }
        ToolbarItem {
            Button("Export…") { project.showExport = true }
                .disabled(!project.canExport || exporter.isRunning)
        }
    }

    private func drop(_ providers: [NSItemProvider]) -> Bool {
        let files = providers.filter { $0.canLoadObject(ofClass: URL.self) }
        guard !files.isEmpty else { return false }
        Task {
            var urls: [URL] = []
            for provider in files {
                if let url = await withCheckedContinuation({ (done: CheckedContinuation<URL?, Never>) in
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in done.resume(returning: url) }
                }) { urls.append(url) }
            }
            project.add(urls)
        }
        return true
    }
}

extension ExportController.State {
    var isIdle: Bool {
        if case .idle = self { true } else { false }
    }
}

extension Project {
    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.movie, .image]
        let finish = { (response: NSApplication.ModalResponse) in
            if response == .OK { self.add(panel.urls) }
        }
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }
}
