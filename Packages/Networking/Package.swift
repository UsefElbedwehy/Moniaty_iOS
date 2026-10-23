// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Networking", targets: ["Networking"])
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        .target(name: "Networking", dependencies: ["Core"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"], swiftSettings: [.swiftLanguageMode(.v6)])
    ]
)
