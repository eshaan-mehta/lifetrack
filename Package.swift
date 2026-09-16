// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Everything",
    platforms: [.iOS("26.0")],
    targets: [
        .executableTarget(
            name: "Everything",
            path: "Sources/Everything",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
