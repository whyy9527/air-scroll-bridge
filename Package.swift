// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AirScrollBridge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AirScrollBridge",
            targets: ["AirScrollBridge"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.60.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.19.0"),
    ],
    targets: [
        .executableTarget(
            name: "AirScrollBridge",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "AirScrollBridgeTests",
            dependencies: ["AirScrollBridge"],
            path: "Tests"
        ),
    ]
)
