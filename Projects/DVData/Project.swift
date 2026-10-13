import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.project(
    name: DVModule.DVData.name,
    targets: [
        .target(
            name: DVModule.DVData.name,
            product: Project.product,
            sources: .sources,
            dependencies: [
                .domain(),
                .core(),
                .argon2(),
            ]
        ),
        .tests(
            name: "DVDataTests",
            sources: ["Tests/**"],
            dependencies: [
                .data(),
            ]
        ),
    ]
)
