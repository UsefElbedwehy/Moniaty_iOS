// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Trust",
    defaultLocalization: "ar",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Trust", targets: ["Trust"])
    ],
    dependencies: [
        .package(path: "../../Core"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Networking"),
        .package(path: "../../Shared")
    ],
    targets: [
        .target(
            name: "Trust",
            dependencies: ["Core", "DesignSystem", "Networking", "Shared"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TrustTests",
            dependencies: ["Trust"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
