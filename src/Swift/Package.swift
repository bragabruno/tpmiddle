// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "TPMiddle",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "TPMiddle",
            targets: ["TPMiddle"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TPMiddle",
            dependencies: [],
            path: ".",
            exclude: ["Package.swift"],
            sources: [
                "HID",
                "Protocols",
                "Utils",
                "Presentation",
                "Application",
                "Configuration",
                "Error"
            ]
        )
    ]
)
