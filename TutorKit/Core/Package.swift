// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TutorCore",
    platforms: [.macOS("15.0")],
    products: [
        .library(name: "TutorCore", targets: ["TutorCore"]),
    ],
    targets: [
        .target(name: "TutorCore"),
        .testTarget(name: "TutorCoreTests", dependencies: ["TutorCore"]),
    ],
    swiftLanguageModes: [.v5]
)
