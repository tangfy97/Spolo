import SwiftUI

@main
struct SpoloApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var project = Project()
    @State private var exporter = ExportController()

    var body: some Scene {
        Window(Text(verbatim: "Spolo"), id: "main") {
            ContentView(project: project, exporter: exporter)
                .onAppear {
                    delegate.onOpen = { urls in project.add(urls) }
                    delegate.onQuit = { project.save() }
                }
        }
        .defaultSize(width: 1100, height: 760)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add…", action: project.chooseFiles)
                    .keyboardShortcut("o")
                Button("Add from Photos…") { project.showPhotosPicker = true }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("Export…") { project.showExport = true }
                    .keyboardShortcut("e")
                    .disabled(!project.canExport || exporter.isRunning)
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Rotate Left") { project.rotateSelection(by: -1) }
                    .keyboardShortcut("l")
                    .disabled(project.selection.isEmpty)
                Button("Rotate Right") { project.rotateSelection(by: 1) }
                    .keyboardShortcut("r")
                    .disabled(project.selection.isEmpty)
                Divider()
                Button("Remove", action: project.removeSelection)
                    .keyboardShortcut(.delete)
                    .disabled(project.selection.isEmpty)
            }
            InspectorCommands()
            // These open in the browser; the app itself has no network access.
            CommandGroup(replacing: .help) {
                Link("Spolo Website", destination: Links.website)
                Link("Support & Privacy", destination: Links.support)
                Link("Contact Support", destination: Links.contact)
                #if !APPSTORE
                Divider()
                Link("Check for a New Version…", destination: Links.newVersion)
                #endif
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pending: [URL] = []
    var onQuit: (() -> Void)?

    var onOpen: (([URL]) -> Void)? {
        didSet {
            if let onOpen, !pending.isEmpty { onOpen(pending) }
            pending = []
        }
    }

    /// Files dropped on the Dock icon or opened with Spolo from Finder.
    func application(_ application: NSApplication, open urls: [URL]) {
        if let onOpen { onOpen(urls) } else { pending += urls }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        onQuit?()
    }
}
