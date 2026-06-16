// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneFPSRecorder",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OneFPSRecorder",
            path: "Sources/OneFPSRecorder",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "OneFPSRecorderSettings",
            path: "Sources/OneFPSRecorderSettings",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
