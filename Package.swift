// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GameChanger",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GameChanger", targets: ["GameChanger"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GameChanger",
            resources: [
                .process("Resources/gamechanger-ui.json"),
                .process("Resources/app_items.json"),
                .process("images/logo"),
                .process("images/svg"),
                .process("images/jpg"),
                .process("images/png"),
                .process("Resources/StartupTwentiethAnniversaryMac.wav")
            ]
        )
    ]
) 