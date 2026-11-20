// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
import CompilerPluginSupport
let package = Package(
    name: "MaXPCe",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "MXI", targets: ["MXI"]),
        .library(name: "MXO", targets: ["MXO"]),
    ],
    targets: [
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
        ),
        .target(
            name: "MXI",
            dependencies: [
                "MAX"
            ],
            path: "MXI/Sources"
        ),
        .target(
            name: "MXO",
            dependencies: ["MAX"],
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
        )
    ]
)
