// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LayoutSwitch",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LayoutSwitch", targets: ["LayoutSwitch"])],
    targets: [
        .target(name: "ShortcutCore"),
        .executableTarget(name: "LayoutSwitch", dependencies: ["ShortcutCore"]),
        .testTarget(name: "ShortcutCoreTests", dependencies: ["ShortcutCore"]),
    ],
    swiftLanguageModes: [.v5]
)
