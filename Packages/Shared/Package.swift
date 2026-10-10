// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shared",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Shared", targets: ["Shared"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../DesignSystem")
    ],
    targets: [
        .target(name: "Shared", dependencies: ["Core", "DesignSystem"], resources: [.process("Resources")], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "SharedTests", dependencies: ["Shared"], swiftSettings: [.swiftLanguageMode(.v6)])
    ]
)
