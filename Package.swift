// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TahoeLaunchpad",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "TahoeLaunchpad",
            path: "Sources"
        ),
    ]
)
