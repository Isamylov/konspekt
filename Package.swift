// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Konspekt",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "KonspektCore"),
        .executableTarget(name: "konspekt", dependencies: ["KonspektCore"]),
        .testTarget(name: "KonspektCoreTests", dependencies: ["KonspektCore"]),
    ],
    swiftLanguageModes: [.v5]
)
