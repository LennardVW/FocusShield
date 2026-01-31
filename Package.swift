// swift-tools-version:6.0
// FocusShield - Complete distraction blocker for macOS

import PackageDescription

let package = Package(
    name: "FocusShield",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "focusshield", targets: ["FocusShield"])],
    targets: [.executableTarget(name: "FocusShield", swiftSettings: [.swiftLanguageMode(.v6)])]
)
