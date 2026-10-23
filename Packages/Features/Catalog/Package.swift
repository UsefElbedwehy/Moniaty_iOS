// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Catalog",
    defaultLocalization: "ar",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Catalog", targets: ["Catalog"])
    ],
    dependencies: [
        .package(path: "../../Core"),
        .package(path: "../../DesignSystem"),
        .package(path: "../../Networking"),
        .package(path: "../../Shared")
    ],
    targets: [
        .target(
            name: "Catalog",
            dependencies: ["Core", "DesignSystem", "Networking", "Shared"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CatalogTests",
            dependencies: ["Catalog"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
