import SwiftUI

/// The window's toolbar: Undo and Redo beside the title, then flat, labelled buttons with a soft hover fill,
/// a divider, and the inspector toggle, filled while it is open. macOS 26 would put each item in a glass
/// capsule; that background is turned off so the toolbar stays quiet.
struct WindowToolbar: ViewModifier {
    @Bindable var project: Project
    let exporter: ExportController
    @Binding var showInspector: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.toolbar { glassless }
        } else {
            content.toolbar { items }
        }
    }

    @ToolbarContentBuilder private var items: some ToolbarContent {
        ToolbarItem(placement: .navigation) { undo }
        ToolbarItem(placement: .navigation) { redo }
        ToolbarItem(placement: .primaryAction) { add }
        ToolbarItem(placement: .primaryAction) { sort }
        ToolbarItem(placement: .primaryAction) { frame }
        ToolbarItem(placement: .primaryAction) { export }
        ToolbarItem(placement: .primaryAction) { divider }
        ToolbarItem(placement: .primaryAction) { inspector }
    }

    @available(macOS 26, *)
    @ToolbarContentBuilder private var glassless: some ToolbarContent {
        ToolbarItem(placement: .navigation) { undo }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .navigation) { redo }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { add }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { sort }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { frame }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { export }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { divider }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { inspector }.sharedBackgroundVisibility(.hidden)
    }

    private var undo: some View {
        Button(action: project.undo) {
            Label("Undo", systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(FlatButtonStyle())
        .help(Text("Undo"))
        .disabled(!project.canUndo)
    }

    private var redo: some View {
        Button(action: project.redo) {
            Label("Redo", systemImage: "arrow.uturn.forward")
        }
        .buttonStyle(FlatButtonStyle())
        .help(Text("Redo"))
        .disabled(!project.canRedo)
    }

    private var add: some View {
        Menu {
            Button("Add…", action: project.chooseFiles)
            Button("Add from Photos…") { project.showPhotosPicker = true }
        } label: {
            Label("Add", systemImage: "plus")
        }
        .flatMenu(titled: true)
        .help(Text("Add photos and videos"))
    }

    private var sort: some View {
        Menu {
            Button("Order Added") { project.sort(.added) }
            Button("Date Taken") { project.sort(.dateTaken) }
            Button("File Name") { project.sort(.name) }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .flatMenu(titled: true)
        .help(Text("Sort the clips"))
        .disabled(project.clips.count < 2)
    }

    /// Shape and fit or fill together, since both decide how each clip sits in the frame.
    private var frame: some View {
        Menu {
            Picker("Shape", selection: Binding(get: { project.layout.shape }, set: { shape in
                project.setLayout("Change Shape") { $0.shape = shape }
            })) {
                ForEach(FrameShape.allCases, id: \.self) { shape in
                    if let name = shape.ratioName { Text(verbatim: name).tag(shape) } else { Text("Auto").tag(shape) }
                }
            }
            .pickerStyle(.inline)
            Picker("Scale", selection: Binding(get: { project.layout.fill }, set: { fill in
                project.setLayout("Change Fill") { $0.fill = fill }
            })) {
                Text("Fit").tag(FillMode.fit)
                Text("Fill").tag(FillMode.fill)
            }
            .pickerStyle(.inline)
        } label: {
            // The current choice is the label, so the button says what it does.
            Label {
                Text(verbatim: frameTitle)
            } icon: {
                Image(systemName: project.layout.shape == .tall || project.layout.shape == .portrait ? "rectangle.portrait" : "rectangle")
            }
        }
        .flatMenu(titled: true)
        .help(Text("Shape of the video, and fit with black bars or fill and crop"))
        .disabled(project.clips.isEmpty)
    }

    private var frameTitle: String {
        let shape = project.layout.shape.ratioName ?? String(localized: "Auto")
        let fill = project.layout.fill == .fit ? String(localized: "Fit") : String(localized: "Fill")
        return "\(shape) · \(fill)"
    }

    private var export: some View {
        Button { project.showExport = true } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(FlatButtonStyle(titled: true))
        .help(Text("Export…"))
        .disabled(!project.canExport || exporter.isRunning)
    }

    private var divider: some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 1, height: 18)
            .padding(.horizontal, 4)
    }

    private var inspector: some View {
        Button { showInspector.toggle() } label: {
            Label("Inspector", systemImage: "sidebar.trailing")
        }
        .buttonStyle(FlatButtonStyle(active: showInspector && !project.clips.isEmpty))
        .help(Text("Show or hide the inspector"))
        .disabled(project.clips.isEmpty)
    }
}

/// A toolbar button without a bezel: an icon, or an icon and a word with `titled`.
/// `active` gives it the filled square that marks something switched on.
struct FlatButtonStyle: ButtonStyle {
    var titled = false
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        Flat(label: configuration.label, titled: titled, pressed: configuration.isPressed, active: active)
    }

    private struct Flat<Label: View>: View {
        let label: Label
        let titled: Bool
        let pressed: Bool
        let active: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            Group {
                if titled {
                    label
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 9)
                } else {
                    label
                        .labelStyle(.iconOnly)
                        .font(.system(size: 15, weight: .regular))
                        .frame(width: 32)
                }
            }
            .foregroundStyle(enabled ? (active ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)) : AnyShapeStyle(.quaternary))
            .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(fill))
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }

        private var fill: Double {
            guard enabled else { return 0 }
            if pressed || active { return 0.12 }
            return hovering ? 0.07 : 0
        }
    }
}

private extension View {
    /// A pull-down menu that looks like a flat toolbar icon, without the disclosure chevron.
    func flatMenu(titled: Bool = false) -> some View {
        menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(FlatButtonStyle(titled: titled))
            .fixedSize()
    }
}
