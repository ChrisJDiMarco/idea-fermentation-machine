// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "IdeaFermentationMachine",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "IdeaFermentationCore", targets: ["IdeaFermentationCore"]),
        .library(name: "IdeaFermentationApp", targets: ["IdeaFermentationApp"]),
        .executable(name: "IdeaFermentationMachine", targets: ["IdeaFermentationMain"])
    ],
    targets: [
        .target(
            name: "IdeaFermentationCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Security"),
                .linkedFramework("PDFKit"),
                .linkedFramework("Vision"),
                .linkedFramework("NaturalLanguage"),
                .linkedFramework("AppKit")
            ]
        ),
        .target(
            name: "IdeaFermentationApp",
            dependencies: ["IdeaFermentationCore"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Network")
            ]
        ),
        .executableTarget(
            name: "IdeaFermentationMain",
            dependencies: ["IdeaFermentationApp"],
            path: "Sources/IdeaFermentationMain",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "IdeaFermentationCoreTests",
            dependencies: ["IdeaFermentationCore"]
        ),
        .testTarget(
            name: "IdeaFermentationAppTests",
            dependencies: ["IdeaFermentationApp", "IdeaFermentationCore"]
        )
    ]
)
