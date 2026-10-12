// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TVMazeKit",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        // macOS only so `swift test` runs on CI; the views are made for Apple TV and iPhone.
        .macOS(.v14),
    ],
    products: [
        .library(name: "TVMazeKit", targets: ["TVMazeKit"]),
        .library(name: "TVMazeUI", targets: ["TVMazeUI"]),
    ],
    targets: [
        .target(name: "TVMazeKit"),
        .target(name: "TVMazeUI", dependencies: ["TVMazeKit"]),
        .testTarget(
            name: "TVMazeKitTests",
            dependencies: ["TVMazeKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
