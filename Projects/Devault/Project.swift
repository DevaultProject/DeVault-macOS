import ProjectDescription
import ProjectDescriptionHelpers

// MARK: - Signing

/// Apple Developer 팀 시트가 없는 팀원을 위한 로컬 빌드 스위치.
///
/// `TUIST_LOCAL_SIGNING=1 tuist generate`로 켜면 iCloud entitlement를 떼고 ad-hoc 서명으로 빌드한다.
/// entitlement가 없으면 CloudKit 계정 조회가 `.configurationUnavailable`로 떨어져 동기화가 켜지지 않으므로,
/// iCloud를 제외한 나머지 기능은 그대로 확인할 수 있다.
///
/// TODO: 팀 시트를 전원에게 발급하면 이 분기와 아래 두 설정 딕셔너리를 제거한다. (#64)
let isLocalSigning = Environment.localSigning.getBoolean(default: false)

/// CI에서 App Store 배포 아카이브를 만들 때 켠다. `ci_post_clone.sh`가 `TUIST_CI_SIGNING=1`로 설정한다.
let isCISigning = Environment.ciSigning.getBoolean(default: false)

/// 아카이브 빌드 번호(CFBundleVersion). App Store는 업로드마다 고유·증가값을 요구하므로
/// CI에선 `$CI_BUILD_NUMBER`를 주입하고, 로컬은 기본값 "40"을 쓴다.
let buildNumber = Environment.buildNumber.getString(default: "40")

/// 로컬 StoreKit 테스트 스토어를 실행 스킴에 붙인다. `generate-storekit`이 `TUIST_STORE_KIT_TESTING=1`로 설정한다.
///
/// **기본값이 꺼짐인 이유는 `Devault.storekit`이 git으로 추적되지 않기 때문이다.** 공유 스킴은 커밋되므로, 항상 붙이면 파일을 받지 않은 팀원의 스킴이 없는 경로를 가리킨다. 파일을 별도로 전달받은 사람만 켠다.
let isStoreKitTesting = Environment.storeKitTesting.getBoolean(default: false)

let teamSigningSettings: SettingsDictionary = [
    "ASSETCATALOG_COMPILER_APPICON_NAME": "Devault_IC",
    "DEVELOPMENT_TEAM": "UKY6HK6U6Y",
    // Tuist가 macOS 타겟에 CODE_SIGN_IDENTITY = "-"(ad-hoc)를 기본으로 넣는데,
    // iCloud entitlement는 프로비저닝 프로파일을 요구하므로 그대로 두면 서명 단계에서 빌드가 실패한다.
    "CODE_SIGN_STYLE": "Automatic",
    "CODE_SIGN_IDENTITY": "Apple Development",
]

/// CI 배포용. team 설정은 로컬 개발 탓에 서명 아이덴티티를 "Apple Development"로 고정하는데,
/// 그대로 아카이브하면 개발 인증서로 서명돼 App Store 업로드가 거부된다. 그래서 "Apple Distribution"으로 둔다.
let ciSigningSettings: SettingsDictionary = [
    "ASSETCATALOG_COMPILER_APPICON_NAME": "Devault_IC",
    "DEVELOPMENT_TEAM": "UKY6HK6U6Y",
    "CODE_SIGN_STYLE": "Automatic",
    "CODE_SIGN_IDENTITY": "Apple Distribution",
]

let localSigningSettings: SettingsDictionary = [
    "ASSETCATALOG_COMPILER_APPICON_NAME": "Devault_IC",
    "CODE_SIGN_STYLE": "Manual",
    // Sign to Run Locally. 프로비저닝 프로파일 없이 서명하므로 Apple ID 자체가 필요 없다.
    "CODE_SIGN_IDENTITY": "-",
]

/// 남의 계정에서 받은 인증서·프로파일로 서명할 때 쓰는 값. `generate-signed`가 채워준다.
///
/// 개인(Individual) Apple Developer Program은 **팀원 초대가 불가능**하므로, 그 계정의 팀으로
/// Automatic 서명을 할 수 없다. 인증서와 프로비저닝 프로파일을 받아 Manual로 서명하는 게
/// 유일한 경로다. 팀 ID·프로파일 이름은 개인 자산이라 리포에 두지 않고 환경변수로 받는다.
let manualSigningTeam = Environment.manualSigningTeam.getString(default: "")
let manualSigningProfile = Environment.manualSigningProfile.getString(default: "")
let isManualSigning = !manualSigningTeam.isEmpty && !manualSigningProfile.isEmpty

/// 로컬 서명과 달리 entitlements를 그대로 유지한다 — 프로파일이 그 entitlement를 담고 있어야
/// 서명이 통과하며, 이 모드의 목적 자체가 iCloud·키체인 그룹을 실제로 얻는 것이다.
let manualSigningSettings: SettingsDictionary = [
    "ASSETCATALOG_COMPILER_APPICON_NAME": "Devault_IC",
    "DEVELOPMENT_TEAM": .string(manualSigningTeam),
    "CODE_SIGN_STYLE": "Manual",
    "CODE_SIGN_IDENTITY": "Apple Development",
    "PROVISIONING_PROFILE_SPECIFIER": .string(manualSigningProfile),
]

/// 로컬 서명이 가장 우선한다 — 자산을 받아둔 뒤에도 `generate-local`로 되돌릴 수 있어야 한다.
/// CI 서명은 그다음 — CI에서만 `TUIST_CI_SIGNING`이 켜진다.
let signingSettings: SettingsDictionary = {
    if isLocalSigning { return localSigningSettings }
    if isCISigning { return ciSigningSettings }
    if isManualSigning { return manualSigningSettings }
    return teamSigningSettings
}()

/// 실행 스킴에 얹을 옵션. StoreKit 테스트가 꺼져 있으면 아무것도 얹지 않는다.
///
/// 붙어 있으면 실제 샌드박스 대신 `Devault.storekit`의 상품으로 구매가 이뤄져, App Store Connect 상품 등록이나 유료 계약 승인 없이도 구매·갱신·만료·환불·복원을 검증할 수 있다. 실제 Sandbox 계정으로 검증할 때는 꺼야 한다.
let storeKitOptions: RunActionOptions = isStoreKitTesting
    ? .options(storeKitConfigurationPath: .relativeToManifest("Devault.storekit"))
    : .options()

// MARK: - Project

let project = Project.project(
    name: DVModule.Devault.name,
    targets: [
        .target(
            name: DVModule.Devault.name,
            product: .app,
            bundleId: "com.devault.app",
            infoPlist: .extendingDefault(with: [
                // 사용자에게 보이는 이름. 메뉴바는 CFBundleName, Finder·Launchpad는 CFBundleDisplayName을 쓰므로 둘 다 저장
                "CFBundleDisplayName": .string("DeVault"),
                "CFBundleName": .string("DeVault"),
                // Mac App Store 필수. 여기엔 주 카테고리(생산성)만 들어감
                "LSApplicationCategoryType": .string("public.app-category.productivity"),
                // 마케팅 버전(기본값 "1.0"을 덮어쓴다).
                "CFBundleShortVersionString": .string("1.0.0"),
                "CFBundleVersion": .string(buildNumber),
                // 표준 AES-GCM(CryptoKit)만 사용 → 수출 규정 면제 대상.
                "ITSAppUsesNonExemptEncryption": .boolean(false),
                "NSFaceIDUsageDescription": .string("저장된 시크릿을 안전하게 보호하기 위해 Touch ID를 사용합니다."),
                // About 패널·App Store에 노출.
                "NSHumanReadableCopyright": .string("Copyright © 2026 Devault. All rights reserved."),
                "CFBundleLocalizations": .array([.string("en"), .string("ko")]),
            ]),
            sources: .sources,
            resources: [.glob(pattern: "Resources/**", excluding: ["Resources/*.entitlements"])],
            entitlements: isLocalSigning ? nil : .file(path: "Resources/Devault.entitlements"),
            dependencies: [
                // internal dependency
                .presentation(),
                .data(),
                .domain(),
                .core(),

                // 3rd-party dependency
                .tca(),
            ],
            settings: .settings(base: signingSettings)
        ),
        // StoreKit은 앱 번들 신원이 있어야 거래하므로 호스트 없는 유닛 번들에서는 상품 조회가 빈 배열로 떨어진다. 앱을 의존성으로 두면 Tuist가 TEST_HOST를 잡아준다.
        .tests(
            name: "DevaultTests",
            dependencies: [
                .target(name: DVModule.Devault.name),
                .data(),
                .domain(),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: DVModule.Devault.name,
            buildAction: .buildAction(targets: [.target(DVModule.Devault.name)]),
            testAction: .targets([.testableTarget(target: .target("DevaultTests"))]),
            runAction: .runAction(
                configuration: .debug,
                executable: .target(DVModule.Devault.name),
                arguments: .arguments(
                    launchArguments: [
                        .launchArgument(name: "-com.apple.CoreData.CloudKitDebug 1", isEnabled: true),
                    ]
                ),
                options: storeKitOptions
            )
        ),
    ]
)
