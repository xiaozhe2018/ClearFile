// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClearFile",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClearFile", targets: ["ClearFile"])
    ],
    targets: [
        .executableTarget(
            name: "ClearFile",
            path: "Sources/ClearFile"
        ),
        .testTarget(
            name: "ClearFileTests",
            dependencies: ["ClearFile"],
            path: "Tests/ClearFileTests"
        )
    ]
)
