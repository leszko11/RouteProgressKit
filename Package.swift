// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RouteProgressKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1)
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
