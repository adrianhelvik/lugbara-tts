// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Lugbara",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Lugbara", path: "Sources/Lugbara"),
        .testTarget(name: "LugbaraTests", dependencies: ["Lugbara"], path: "Tests/LugbaraTests"),
    ]
)
