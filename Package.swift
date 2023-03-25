// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ChatGPT",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "ChatGPT",
            targets: ["ChatGPT"]),
    ],
    targets: [
        .target(
            name: "ChatGPT",
            dependencies: []),
    ]
)
