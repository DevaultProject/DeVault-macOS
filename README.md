# 🔒 DeVault

![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-16%2B-147EFB?logo=xcode&logoColor=white)
![Tuist](https://img.shields.io/badge/Tuist-4.202.0-4F44D6)
![SPM](https://img.shields.io/badge/Dependencies-Swift%20Package%20Manager-orange?logo=swift&logoColor=white)
![TCA](https://img.shields.io/badge/TCA-1.26.0%2B-5F5FC4)

> 개발자를 위한 macOS 시크릿 관리 애플리케이션

<a href="https://apps.apple.com/kr/app/devault-secure-dev-secrets/id6802093482?mt=12"><img src="docs/images/app-store-badge.svg" alt="Download on the App Store" width="230"></a>

![DeVault on MacBook](docs/images/devault-hero.png)

## 🚀 프로젝트 소개

- **개발 기간:** 2026.03 ~ 현재
- **프로젝트 목표:** DeVault(Dev + Vault)는 macOS에서 개발자가 사용하는 API 키, 토큰, 환경 변수 등의 시크릿을 관리하는 네이티브 애플리케이션입니다. 로컬 우선 아키텍처를 바탕으로 시크릿을 기기에 암호화해 저장하고, 개발 워크플로우에 자연스럽게 녹아드는 사용 경험을 제공합니다.

---

## ✨ 주요 기능

<br>

### 1. 다양한 시크릿 지원

API 키와 액세스 토큰, 웹훅 시크릿, OAuth 정보, 데이터베이스 접속 정보, SSH 키, SSL/TLS 인증서, 환경 변수 세트, 라이선스 키 등을 유형별 입력 폼으로 관리합니다.

| 시크릿 등록 | 시크릿 열람 및 수정 |
|:---:|:---:|
| <img src="docs/images/secret-registration.gif" alt="시크릿 등록" width="420"> | <img src="docs/images/secret-view-edit.gif" alt="시크릿 열람 및 수정" width="420"> |

<br>

### 2. 프로젝트·환경별 시크릿 관리

시크릿을 프로젝트에 연결하고 개발·스테이징·프로덕션 환경을 지정해 관리합니다. 즐겨찾기와 검색·필터·정렬 기능으로 필요한 시크릿을 빠르게 찾을 수 있습니다.

| 시크릿 검색 | 빠른 찾기 메뉴 |
|:---:|:---:|
| <img src="docs/images/secret-search.gif" alt="시크릿 검색" width="420"> | <img src="docs/images/quick-find-menu.gif" alt="빠른 찾기 메뉴" width="420"> |

<br>

### 3. 보안 정책

시크릿 열람과 복사, 수정 등 민감한 작업에 Touch ID 또는 Mac 사용자 인증을 사용하고, 일정 시간 사용하지 않으면 앱을 자동으로 잠급니다. 복사한 값은 설정한 시간이 지나면 클립보드에서 삭제하며, 화면 캡처 보호와 반복 인증 실패·복사 감지 알림을 제공합니다.

| 클립보드 자동 삭제 | 앱 자동 잠금 |
|:---:|:---:|
| <img src="docs/images/clipboard-auto-clear.gif" alt="클립보드 자동 삭제" width="420"> | <img src="docs/images/app-auto-lock.gif" alt="앱 자동 잠금" width="420"> |

| 화면 캡처 보호 |
|:---:|
| <img src="docs/images/screen-capture-protection.png" alt="화면 캡처 보호" width="650"> |

<br>

### 4. 만료 관리와 알림

시크릿별 만료일을 설정하고 만료 30일·7일·3일 전 또는 만료 당일에 알림을 받도록 설정할 수 있습니다.

| 만료 및 보안 알림 설정 |
|:---:|
| <img src="docs/images/notification-settings.png" alt="만료 및 보안 알림 설정" width="650"> |

<br>

### 5. iCloud 동기화

암호화된 시크릿 데이터를 iCloud를 통해 동기화해 사용하는 Mac에서 이어서 관리할 수 있습니다.

| iCloud 동기화 설정 |
|:---:|
| <img src="docs/images/icloud-sync.png" alt="iCloud 동기화 설정" width="650"> |

<br>

### 6. 테마와 DeVault Pro

시스템 설정에 맞추거나 라이트·다크 모드를 선택할 수 있습니다. DeVault Pro 구독으로 시크릿과 프로젝트를 제한 없이 관리하고, iCloud 동기화와 여러 만료 알림 시점을 사용할 수 있습니다.

| 라이트 모드 | 다크 모드 |
|:---:|:---:|
| <img src="docs/images/theme-light.png" alt="라이트 모드" width="420"> | <img src="docs/images/theme-dark.png" alt="다크 모드" width="420"> |

무료 버전은 시크릿 15개, 프로젝트 1개까지 사용할 수 있으며 보안 기능을 포함합니다.

| DeVault Pro 구독 화면 | DeVault Pro 혜택 및 구독 관리 |
|:---:|:---:|
| <img src="docs/images/devault-pro-paywall.png" alt="DeVault Pro 구독 화면" width="420"> | <img src="docs/images/devault-pro.png" alt="DeVault Pro 혜택 및 구독 관리" width="420"> |

---

## 🛠 기술 스택

- **언어·UI:** Swift, SwiftUI
- **상태 관리:** The Composable Architecture (TCA)
- **프로젝트 구성:** Tuist
- **외부 패키지 관리:** Swift Package Manager (Tuist 연동)
- **저장·동기화:** SwiftData, CloudKit
- **보안:** CryptoKit (AES-GCM), Keychain, LocalAuthentication
- **결제:** StoreKit 2

## 🧩 모듈 구조

Tuist로 모듈마다 독립된 Xcode 프로젝트를 구성했습니다. 화면과 비즈니스 규칙, 데이터 구현을 분리하고, 앱 모듈에서 실제 구현체를 조립합니다.

| 모듈 | 역할 |
|---|---|
| `Devault` | macOS 앱 진입점 및 조립 지점. 데이터·도메인 구현체와 프레젠테이션 기능을 연결합니다. |
| `DVPresentation` | SwiftUI 화면, TCA 기반 기능 상태와 액션, 사용자 인터페이스 로직을 담당합니다. |
| `DVDomain` | 도메인 모델, 유스케이스, 저장소·서비스 인터페이스, 시크릿 탐지 규칙을 정의합니다. |
| `DVData` | 도메인 인터페이스를 구현하고 SwiftData 저장, 암호화·인증, iCloud 동기화 등 데이터 작업을 담당합니다. |
| `DVDesign` | 여러 화면에서 재사용하는 디자인 시스템과 UI 컴포넌트를 제공합니다. |
| `DVCore` | 로깅 등 공통 기반 기능을 제공합니다. |
| `DVNetwork`, `DVStorage` | 향후 확장을 위해 준비한 모듈이며 현재 앱 기능에서는 사용하지 않습니다. |

![Tuist 모듈 의존성 그래프](docs/images/module-dependencies.png)

## 🗂 폴더 구조

```text
Projects/
├── Devault/
│   ├── Sources/
│   │   └── Composition/
│   │       ├── AppShell/
│   │       ├── Dependencies/
│   │       └── Graph/
│   └── Resources/
├── DVPresentation/
│   ├── Sources/
│   │   ├── Features/
│   │   │   ├── CreateProject/
│   │   │   ├── CreateSecret/
│   │   │   ├── Lock/
│   │   │   ├── Main/
│   │   │   ├── Onboarding/
│   │   │   ├── SecretDetail/
│   │   │   ├── SecretList/
│   │   │   ├── SelectSecretType/
│   │   │   ├── Settings/
│   │   │   └── Sidebar/
│   │   ├── Dependencies/
│   │   ├── Form/
│   │   ├── Localization/
│   │   └── AppMenu/
│   └── Resources/
├── DVDomain/
│   └── Sources/
│       ├── Detection/
│       │   ├── Detector/
│       │   ├── Model/
│       │   ├── Rule/
│       │   ├── Security/
│       │   └── Support/
│       ├── Entity/
│       ├── Repository/
│       │   ├── Error/
│       │   ├── Interface/
│       │   └── Model/
│       ├── SecretContent/
│       │   ├── Metadata/
│       │   └── Payload/
│       ├── Service/
│       │   ├── Error/
│       │   └── Interface/
│       └── UseCase/
│           ├── Draft/
│           ├── Error/
│           ├── Impl/
│           └── Interface/
├── DVData/
│   └── Sources/
│       ├── RepositoryImpl/
│       │   ├── DataReset/
│       │   ├── Project/
│       │   ├── Secret/
│       │   └── Settings/
│       ├── ServiceImpl/
│       │   ├── App/
│       │   ├── Authentication/
│       │   ├── Clipboard/
│       │   ├── ICloudSync/
│       │   ├── Notification/
│       │   ├── Purchase/
│       │   ├── Security/
│       │   └── Settings/
│       └── Storage/
│           └── Local/
│               └── Models/
├── DVDesign/
│   ├── Sources/
│   │   ├── Components/
│   │   ├── Extensions/
│   │   └── Foundations/
│   │       ├── Color/
│   │       ├── Expiry/
│   │       ├── Fonts/
│   │       ├── Image/
│   │       ├── Motion/
│   │       ├── ServiceLogo/
│   │       ├── Sizing/
│   │       └── Tooltip/
│   ├── Resources/
│   └── SampleApp/
├── DVCore/
│   └── Sources/
│       ├── Formatting/
│       └── Logger/
├── DVNetwork/  # 향후 확장용
└── DVStorage/  # 향후 확장용
```

## 👥 팀원 소개

<table>
  <tr>
    <td align="center"><a href="https://github.com/doyeonk429"><img src="https://github.com/doyeonk429.png?size=200" width="120" alt="김도연 GitHub 프로필 사진"><br>김도연</a></td>
    <td align="center"><a href="https://github.com/yeseonglee"><img src="https://github.com/yeseonglee.png?size=200" width="120" alt="이예성 GitHub 프로필 사진"><br>이예성</a></td>
    <td align="center"><a href="https://github.com/dlguszoo"><img src="https://github.com/dlguszoo.png?size=200" width="120" alt="이현주 GitHub 프로필 사진"><br>이현주</a></td>
  </tr>
</table>

---

## 📄 라이선스

이 프로젝트는 [MIT License](LICENSE)를 따릅니다.
