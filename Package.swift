// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ADBRemote",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "ADBRemote", targets: ["ADBRemote"])
    ],
    targets: [
        .executableTarget(name: "ADBRemote"),
        .testTarget(name: "ADBRemoteTests", dependencies: ["ADBRemote"])
    ]
)
