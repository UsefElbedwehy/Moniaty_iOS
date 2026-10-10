// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderStudio",
    defaultLocalization: "ar",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ProviderStudio", targets: ["ProviderStudio"])
    ],
    dependencies: [
        .package(path: "../../Core"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Networking"),
        .package(path: "../../Shared"),
        .package(path: "../Catalog")
    ],
    targets: [
        .target(
            name: "ProviderStudio",
            dependencies: ["Core", "DesignSystem", "Networking", "Shared", .product(name: "Catalog", package: "Catalog")],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ProviderStudioTests",
            dependencies: ["ProviderStudio"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
