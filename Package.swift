// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Biodag",
    platforms: [
        .iOS(.v16)
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
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "BiodagTests",
            dependencies: ["Biodag"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
