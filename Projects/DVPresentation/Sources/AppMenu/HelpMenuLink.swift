// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

// MARK: - HelpMenuLink

/// store 액션이 아니라 외부 URL을 여는 항목이라 ``AppMenuCommand``와 분리한다.
/// (온보딩·잠금 화면에서도 항상 열 수 있어야 하므로 활성 조건도 없다.)
enum HelpMenuLink: CaseIterable, Hashable {
  case help
  case termsOfService
  case privacyPolicy
  case sendFeedback

  /// 메뉴에 노출되는 순서.
  static let all: [HelpMenuLink] = HelpMenuLink.allCases

  var title: String {
    switch self {
    case .help:          .module("DeVault Help")
    case .termsOfService: .module("Terms of Service")
    case .privacyPolicy: .module("Privacy Policy")
    case .sendFeedback:  .module("Send Feedback")
    }
  }

  var url: URL {
    switch self {
    case .help:          URL(string: "https://devault-devteam.notion.site/")!
    case .termsOfService: URL(string: "https://devault-devteam.notion.site/terms-of-service")!
    case .privacyPolicy: URL(string: "https://devault-devteam.notion.site/privacy-policy")!
    case .sendFeedback:  Self.feedbackMailURL
    }
  }
}

// MARK: - Feedback mail template

extension HelpMenuLink {

  /// 문의 메일에 앱/기기 정보를 미리 채워 둔다 — 사용자가 버전·OS를 직접 적지 않아도 서포트가
  /// 바로 재현 환경을 파악할 수 있게 하기 위해서다. 메일 앱에서 전송 전 자유롭게 수정·삭제할 수
  /// 있으므로, 시리얼 번호 같은 개인 식별 정보는 넣지 않는다.
  private static var feedbackMailURL: URL {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = "devault.devteam@gmail.com"
    components.queryItems = [
      URLQueryItem(name: "subject", value: "[DeVault] "),
      URLQueryItem(name: "body", value: feedbackBody),
    ]
    return components.url!
  }

  /// 서포트가 어느 로캘에서 열어도 똑같이 읽혀야 하는 진단 정보라 `String.module` 로컬라이즈를
  /// 쓰지 않고 라벨을 영어로 고정한다.
  private static var feedbackBody: String {
    """
    Type: [Bug / Feature / Other]
    What happened:
    Steps to reproduce (optional):

    ---
    App Version: \(appVersion)
    macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
    Mac: \(macModelIdentifier)
    Plan: \(entitlement.rawValue.capitalized)
    """
  }

  private static var entitlement: Entitlement {
    @Dependency(\.entitlementClient) var entitlementClient
    return entitlementClient.current()
  }

  private static var appVersion: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "-"
    let build = info?["CFBundleVersion"] as? String ?? "-"
    return "\(version) (\(build))"
  }

  private static var macModelIdentifier: String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    guard size > 0 else { return "-" }
    var buffer = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &buffer, &size, nil, 0)
    return String(cString: buffer)
  }
}
