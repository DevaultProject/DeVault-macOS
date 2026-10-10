// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescription
import ProjectDescriptionHelpers

let packageSettings = PackageSettings(
    productTypes: [
        "ComposableArchitecture": .staticFramework,
    ],
    // Tuist가 매크로 타겟(swift-syntax)에 배포 타겟을 전파 못 하는 버그 우회 (Xcode 27+ 아카이브 실패 방지)
    baseSettings: .settings(base: ["MACOSX_DEPLOYMENT_TARGET": "14.0"])
)
#endif

let package = Package(
    name: "Devault",
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.26.0"
        ),
        .package(
            url: "https://github.com/airbnb/lottie-spm",
            from: "4.6.0"
        ),
    ]
)
