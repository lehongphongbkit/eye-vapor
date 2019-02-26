// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "EYEVapor",
    products: [
        .library(name: "App", targets: ["App"]),
        .executable(name: "Run", targets: ["Run"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "2.1.0")),
        .package(url: "https://github.com/vapor/fluent-provider.git", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/vapor/mysql-provider.git", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/vapor/auth.git", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/nodes-vapor/admin-panel.git", .upToNextMajor(from: "1.0.2")),
        .package(url: "https://github.com/vapor/leaf-provider.git", .upToNextMajor(from: "1.1.0")),
        .package(url: "https://github.com/matthijs2704/vapor-apns.git", .upToNextMajor(from: "2.1.0")),
        .package(url: "https://github.com/manGoweb/S3.git", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/vapor/validation-provider.git", .upToNextMajor(from: "1.2.0"))
    ],
    targets: [
        .target(name: "App", dependencies: ["Vapor","MySQLProvider", "FluentProvider", "AdminPanel", "LeafProvider", "VaporAPNS", "S3", "ValidationProvider"],
                exclude: [
                    "Config",
                    "Public",
                    "Resources",
                    ]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App", "Testing"])
    ]
)

