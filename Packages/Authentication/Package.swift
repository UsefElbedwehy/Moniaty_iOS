// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Authentication",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Authentication", targets: ["Authentication"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../DesignSystem"),
        .package(path: "../Networking"),
        .package(path: "../Shared")
    ],
    targets: [
        .target(
            name: "Authentication",
            dependencies: ["Core", "DesignSystem", "Networking", "Shared"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AuthenticationTests",
            dependencies: ["Authentication"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
