// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyOllama",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MyOllama",
            targets: ["MyOllama"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MyOllama",
            path: "Sources"
        )
    ]
)
