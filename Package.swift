// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "GottaGoFast",
    products: [
        .library(name: "GottaGoFast", targets: ["GottaGoFast"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "2.0.0")
    ],
    targets: [
        .target(name: "GottaGoFast", dependencies: ["Yams"])
    ]
)
