// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MaXPCe",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "MaXPCe.MXO", targets: ["MXO"])
    ],
    targets: [
        .executableTarget(
            name: "MXO-Example",
            dependencies: ["MXO"],
            path: "MXO/Example"
        ),
        .target(
            name: "MXO",
            path: "MXO/Sources"
        ),
        .target(
            name: "MXI",
            path: "MXI/Sources"
        )
    ]
)
