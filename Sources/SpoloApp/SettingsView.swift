import SwiftUI

/// Settings keys, shared by the Settings window, the export sheet and the project.
enum Preference {
    static let photoDuration = "photoDuration"
    static let reopenClips = "reopenClips"
    static let revealAfterExport = "revealAfterExport"
    static let format = "format"
    static let quality = "quality"

    static func register() {
        UserDefaults.standard.register(defaults: [photoDuration: 3.0, reopenClips: true, revealAfterExport: false])
    }

    static var defaultPhotoDuration: Double { UserDefaults.standard.double(forKey: photoDuration) }
}

struct SettingsView: View {
    @AppStorage(Preference.photoDuration) private var photoDuration = 3.0
    @AppStorage(Preference.reopenClips) private var reopenClips = true
    @AppStorage(Preference.revealAfterExport) private var revealAfterExport = false
    @AppStorage(Preference.format) private var format = ExportFormat.mp4
    @AppStorage(Preference.quality) private var quality = ExportQuality.original

    var body: some View {
        Form {
            Section {
                LabeledContent("Photo Duration") {
                    Stepper {
                        Text("\(TimeText.seconds(photoDuration)) s")
                            .monospacedDigit()
                    } onIncrement: {
                        photoDuration = InspectorView.step(photoDuration, by: 1)
                    } onDecrement: {
                        photoDuration = InspectorView.step(photoDuration, by: -1)
                    }
                }
                Toggle("Reopen Last Clips at Launch", isOn: $reopenClips)
            }
            Section("Export") {
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
                Toggle("Show in Finder When Done", isOn: $revealAfterExport)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 440)
        .fixedSize()
    }
}
