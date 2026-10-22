import Foundation
import SpoloCore

// Command-line access to the engine, for testing merges without the app.
//
//   spolo probe <file>...
//   spolo merge -o out.mp4 [--shape auto|16:9|9:16|1:1|4:5] [--fill] [--quality original|high|smaller] <file[@edits]>...
//
// Edits follow the file name after "@", separated by commas:
//   speed=2  trim=<start>:<end> (seconds cut off each end)  mute  turn=<quarter turns clockwise>  dur=<photo seconds>

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func parseClip(_ argument: String) -> (URL, ClipEdits) {
    let parts = argument.split(separator: "@", maxSplits: 1).map(String.init)
    var edits = ClipEdits()
    for edit in parts.count > 1 ? parts[1].split(separator: ",").map(String.init) : [] {
        let pair = edit.split(separator: "=", maxSplits: 1).map(String.init)
        switch (pair[0], pair.count > 1 ? pair[1] : "") {
        case ("speed", let v): edits.speed = Double(v) ?? 1
        case ("mute", _): edits.muted = true
        case ("turn", let v): edits.quarterTurns = Int(v) ?? 0
        case ("dur", let v): edits.photoDuration = Double(v) ?? 3
        case ("trim", let v):
            let ends = v.split(separator: ":").map { Double($0) ?? 0 }
            edits.trimStart = ends.first ?? 0
            edits.trimEnd = ends.count > 1 ? ends[1] : 0
        default: fail("unknown edit \(edit)")
        }
    }
    return (URL(fileURLWithPath: parts[0]), edits)
}

func describe(_ info: MediaInfo) -> String {
    var text = "\(info.kind.rawValue) \(Int(info.size.width))×\(Int(info.size.height))"
    if info.kind == .video {
        text += String(format: " %.2fs %.2ffps %@", info.duration, info.frameRate, info.codec)
        text += info.hasAudio ? " audio(\(info.audioFormat))" : " no-audio"
        if info.isHDR { text += " HDR" }
    }
    if let date = info.dateTaken { text += " taken \(date.formatted(.iso8601))" }
    return text
}

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { fail("usage: spolo probe|merge …") }
args.removeFirst()

switch command {
case "probe":
    for path in args {
        let info = await MediaProbe.probe(URL(fileURLWithPath: path))
        print("\((path as NSString).lastPathComponent): \(describe(info))")
    }
case "merge":
    var output: URL?
    var layout = Layout()
    var quality = ExportQuality.original
    var clips: [(URL, ClipEdits)] = []
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "-o": output = URL(fileURLWithPath: args.removeFirst())
        case "--fill": layout.fill = .fill
        case "--shape":
            let name = args.removeFirst()
            layout.shape = FrameShape.allCases.first { $0.ratioName == name || $0.rawValue == name } ?? .auto
        case "--quality": quality = ExportQuality(rawValue: args.removeFirst()) ?? .original
        default: clips.append(parseClip(arg))
        }
    }
    guard let output else { fail("merge needs -o <file>") }
    var segments: [Segment] = []
    for (url, edits) in clips {
        let info = await MediaProbe.probe(url)
        print("\(url.lastPathComponent): \(describe(info))")
        segments.append(Segment(url: url, info: info, edits: edits))
    }
    let format: ExportFormat = output.pathExtension.lowercased() == "mov" ? .mov : .mp4
    let exporter = Exporter(segments: segments, layout: layout, format: format, quality: quality)
    print("size \(Timeline.renderSize(segments, layout: layout)), \(String(format: "%.2f", exporter.duration))s, "
          + (exporter.isPassthrough ? "joining without re-encoding" : "re-encoding"))
    let start = Date()
    do {
        try await exporter.export(to: output) { value in
            FileHandle.standardError.write(Data(String(format: "\r%3.0f%%", value * 100).utf8))
        }
    } catch {
        fail("\nfailed: \(error.localizedDescription) \(error)")
    }
    print(String(format: "\nwrote %@ in %.1fs", output.path, Date().timeIntervalSince(start)))
default:
    fail("unknown command \(command)")
}
