// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "YouTubeWidget",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "YouTubeWidget", targets: ["YouTubeWidget"])
    ],
    targets: [
        .executableTarget(
            name: "YouTubeWidget",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "YouTubeWidgetTests",
            dependencies: ["YouTubeWidget"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
