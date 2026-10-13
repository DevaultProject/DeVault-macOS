// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescription
import ProjectDescriptionHelpers

let packageSettings = PackageSettings(
    productTypes: [
        "ComposableArchitecture": .staticFramework,
    ],
    // SwiftCompilerPlugin을 쓰는 매크로 플러그인 타겟만 요구치(12.0)에 맞춤
    targetSettings: [
        "SwiftCompilerPlugin": ["MACOSX_DEPLOYMENT_TARGET": "12.0"],
        "SwiftSyntax601": ["MACOSX_DEPLOYMENT_TARGET": "12.0"],
        "CasePathsMacros": ["MACOSX_DEPLOYMENT_TARGET": "12.0"],
        "ComposableArchitectureMacros": ["MACOSX_DEPLOYMENT_TARGET": "12.0"],
        "PerceptionMacros": ["MACOSX_DEPLOYMENT_TARGET": "12.0"],
        "DependenciesMacrosPlugin": ["MACOSX_DEPLOYMENT_TARGET": "12.0"],
        "SwiftNavigationMacros": ["MACOSX_DEPLOYMENT_TARGET": "12.0"],
    ]
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
