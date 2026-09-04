// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import Foundation
import Testing

@testable import DVPresentation

@Suite("HelpMenuLink")
struct HelpMenuLinkTests {

  @Test("all은 Help·Terms of Service·Privacy Policy·Send Feedback 순서로 구성된다")
  func allContainsLinksInMenuOrder() {
    #expect(HelpMenuLink.all == [.help, .termsOfService, .privacyPolicy, .sendFeedback])
  }

  @Test("Help는 지원 사이트로 연결된다")
  func helpURL() {
    #expect(HelpMenuLink.help.url.absoluteString == "https://devault-devteam.notion.site/")
  }

  @Test("Terms of Service는 이용약관 페이지로 연결된다")
  func termsOfServiceURL() {
    #expect(HelpMenuLink.termsOfService.url.absoluteString == "https://devault-devteam.notion.site/terms-of-service")
  }

  @Test("Privacy Policy는 정책 사이트로 연결된다")
  func privacyPolicyURL() {
    #expect(HelpMenuLink.privacyPolicy.url.absoluteString == "https://devault-devteam.notion.site/privacy-policy")
  }

  @Test("Send Feedback은 팀 이메일 mailto로 연결되고 subject·body 틀을 담는다")
  func sendFeedbackURL() throws {
    // 피드백 본문의 Plan 줄이 entitlementClient.current()를 읽으므로 테스트가 등급을 명시한다.
    let url = withDependencies {
      $0.entitlementClient.current = { .free }
    } operation: {
      HelpMenuLink.sendFeedback.url
    }
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

    #expect(url.scheme == "mailto")
    #expect(components.path == "devault.devteam@gmail.com")

    let body = try #require(components.queryItems?.first { $0.name == "body" }?.value)
    #expect(body.contains("Type:"))
    #expect(body.contains("What happened:"))
    #expect(body.contains("Steps to reproduce"))
    #expect(body.contains("App Version:"))
    #expect(body.contains("macOS:"))
    #expect(body.contains("Mac:"))
    #expect(body.contains("Plan:"))
  }
}
