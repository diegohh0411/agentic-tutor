// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TutorKit",
    platforms: [.macOS("15.0")],
    products: [
        .library(name: "TutorCore", targets: ["TutorCore"]),
        .library(name: "TutorEngines", targets: ["TutorEngines"]),
        .library(name: "TutorAudio", targets: ["TutorAudio"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soniqo/speech-swift.git", exact: "0.0.28"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "3.31.4"),
        .package(url: "https://github.com/gradium-ai/xn-ptts.git", exact: "0.4.0"),
    ],
    targets: [
        .target(name: "TutorCore"),
        .target(
            name: "TutorEngines",
            dependencies: [
                "TutorCore",
                .product(name: "SpeechVAD", package: "speech-swift"),
                .product(name: "NemotronStreamingASR", package: "speech-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "ptts", package: "xn-ptts"),
            ]
        ),
        .target(name: "TutorAudio", dependencies: ["TutorCore"]),
        .testTarget(name: "TutorCoreTests", dependencies: ["TutorCore"]),
        .testTarget(
            name: "TutorEnginesTests",
            dependencies: ["TutorEngines"],
            resources: [.copy("../Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
