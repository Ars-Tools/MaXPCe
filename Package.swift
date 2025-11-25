// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MaXPCe",
    platforms: [
        .macOS(.v15)
    ],
    products: [
    ],
    targets: [
        .executableTarget(
            name: "Example",
            dependencies: ["MXS"],
            path: "Example/Sources"
        ),
        .target(
            name: "MXS",
            path: "MXS/Sources"
        )
    ]
)
