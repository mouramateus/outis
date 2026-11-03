// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "VPNPais",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "VPNCore"),
        .executableTarget(name: "VPNPais", dependencies: ["VPNCore"]),
        .testTarget(name: "VPNCoreTests", dependencies: ["VPNCore"]),
    ]
)
