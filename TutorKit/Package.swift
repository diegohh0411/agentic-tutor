// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TutorKit",
    platforms: [.macOS("15.0")],
    products: [
        .library(name: "TutorCore", targets: ["TutorCoreExport"]),
        .library(name: "TutorEngines", targets: ["TutorEngines"]),
        .library(name: "TutorAudio", targets: ["TutorAudio"]),
    ],
    dependencies: [
        .package(path: "Core"),
        .package(url: "https://github.com/soniqo/speech-swift.git", exact: "0.0.28"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "3.31.4"),
        .package(url: "https://github.com/gradium-ai/xn-ptts.git", exact: "0.4.0"),
        .package(url: "https://github.com/huggingface/swift-huggingface.git", exact: "1.0.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", exact: "1.3.5"),
    ],
    targets: [
        .target(
            name: "TutorCoreExport",
            dependencies: [.product(name: "TutorCore", package: "Core")]
        ),
        .target(
            name: "TutorEngines",
            dependencies: [
                .product(name: "TutorCore", package: "Core"),
                .product(name: "SpeechVAD", package: "speech-swift"),
                .product(name: "NemotronStreamingASR", package: "speech-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "ptts", package: "xn-ptts"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ]
        ),
        .target(name: "TutorAudio", dependencies: [.product(name: "TutorCore", package: "Core")]),
        .testTarget(
            name: "TutorEnginesTests",
            dependencies: ["TutorEngines"],
            resources: [.copy("../Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
