// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FuelSwitch",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FuelSwitchCore", targets: ["FuelSwitchCore"]),
    ],
    targets: [
        .target(name: "FuelSwitchCore"),
        .executableTarget(name: "FuelSwitch", dependencies: ["FuelSwitchCore"]),
        .testTarget(
            name: "FuelSwitchCoreTests",
            dependencies: ["FuelSwitchCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
