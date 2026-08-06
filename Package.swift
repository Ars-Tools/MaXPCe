// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MaXPCe",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "MaXPCe.MXO", targets: ["MXO"]),
        .library(name: "MaXPCe.MXI", targets: ["MXI"]),
    ],
    targets: [
        .target(
            name: "MXO",
            dependencies: [
                "MAX"
            ],
            path: "MXO/Sources"
        ),
        .executableTarget(
            name: "MXO-Example",
            dependencies: ["MXO"],
            path: "MXO/Example",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64")
            ]
        ),
        .target(
            name: "MXI",
            dependencies: ["MXO"],
            path: "MXI/Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "MXITests",
            dependencies: [
                "MXI"
            ],
            path: "MXI/Tests"
        ),
        .target(
            name: "MAX",
            path: "MAX/Sources"
        ),
        .testTarget(
            name: "MAX-Tests",
            dependencies: [
                "MAX"
            ],
            path: "MAX/Tests"
        )
    ]
)
