// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Spolo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "spolo", targets: ["spolo"]),
    ],
    targets: [
        // The engine: reading media, building the composition, the Core Image compositor and export. No networking.
        .target(name: "SpoloCore", path: "Sources/SpoloCore"),
        // Command-line merge and probe, for testing the engine without the app.
        .executableTarget(name: "spolo", dependencies: ["SpoloCore"], path: "Sources/spolo"),
    ],
    swiftLanguageModes: [.v5]
)
