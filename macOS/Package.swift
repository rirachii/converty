// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConvertyNative",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ConvertyCore", targets: ["ConvertyCore"])],
    targets: [
        .systemLibrary(name: "CArchive"),
        .target(name: "ConvertyCore", dependencies: ["CArchive"]),
        .testTarget(name: "ConvertyCoreTests", dependencies: ["ConvertyCore"])
    ]
)
