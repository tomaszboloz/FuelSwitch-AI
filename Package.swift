// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FuelSwitch",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FuelSwitchCore", targets: ["FuelSwitchCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6"),
    ],
    targets: [
        .target(name: "FuelSwitchCore"),
        .executableTarget(
            name: "FuelSwitch",
            dependencies: [
                "FuelSwitchCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(
            name: "FuelSwitchCoreTests",
            dependencies: ["FuelSwitchCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
