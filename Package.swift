// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LifeTrack",
    platforms: [.iOS("26.0")],
    targets: [
        .executableTarget(
            name: "LifeTrack",
            path: "Sources/LifeTrack",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation"),
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
