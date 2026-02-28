// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwissInvoice",
    platforms: [
            .iOS(.v15),      // Sets minimum iOS version to 15.0
        ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwissInvoice",
            targets: ["SwissInvoice"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwissInvoice"
        ),
        .testTarget(
            name: "SwissInvoiceTests",
            dependencies: ["SwissInvoice"]
        ),
    ]
)
