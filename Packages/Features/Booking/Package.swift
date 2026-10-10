// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Booking",
    defaultLocalization: "ar",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Booking", targets: ["Booking"])
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
            name: "Booking",
            dependencies: ["Core", "DesignSystem", "Networking", "Shared", .product(name: "Catalog", package: "Catalog")],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "BookingTests",
            dependencies: ["Booking"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
