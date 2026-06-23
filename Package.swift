// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SpaceName",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "CGSPrivate",
            path: "Sources/CGSPrivate"
        ),
        .executableTarget(
            name: "SpaceName",
            dependencies: ["CGSPrivate"],
            path: "Sources/SpaceName",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SpaceNameTests",
            dependencies: ["SpaceName"],
            path: "Tests/SpaceNameTests"
        )
    ]
)
