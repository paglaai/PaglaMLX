// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PaglaMLX",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PaglaMLX", targets: ["PaglaMLX"])
    ],
    targets: [
        .executableTarget(
            name: "PaglaMLX",
            path: "Sources"
        ),
        .testTarget(
            name: "PaglaMLXTests",
            dependencies: ["PaglaMLX"],
            path: "Tests"
        )
    ]
)
