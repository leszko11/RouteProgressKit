// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RouteProgressKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .tvOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "RouteProgressKit",
            targets: ["RouteProgressKit"]
        )
    ],
    targets: [
        .target(
            name: "RouteProgressKit"
        ),
        .testTarget(
            name: "RouteProgressKitTests",
            dependencies: ["RouteProgressKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
