// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Biodag",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "Biodag",
            targets: ["Biodag"]
        )
    ],
    targets: [
        .target(
            name: "Biodag",
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "BiodagTests",
            dependencies: ["Biodag"]
        )
    ],
    swiftLanguageModes: [.v6]
)
