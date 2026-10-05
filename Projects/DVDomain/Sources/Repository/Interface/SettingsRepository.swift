// Copyright © 2026 Devault. All rights reserved

import Foundation

public protocol SettingsRepository: Sendable {
  // MARK: - Onboarding

  func hasCompletedOnboarding() -> Bool
  func setOnboardingCompleted()

  // MARK: - iCloud

  func isICloudSyncEnabled() -> Bool
  func setICloudSyncEnabled(_ enabled: Bool)

  func iCloudLastUpdateDetectedAt() -> Date?
  func setICloudLastUpdateDetectedAt(_ date: Date)

  // MARK: - General

  func isLaunchAtLoginEnabled() -> Bool
  func setLaunchAtLoginEnabled(_ enabled: Bool)

  /// 새 Secret 생성 시 자동 적용되는 기본 환경(rawValue).
  func defaultEnvironment() -> String
  func setDefaultEnvironment(_ rawValue: String)

  /// 앱 전체에 적용할 화면 모드(rawValue: system/light/dark).
  func appearance() -> String
  func setAppearance(_ rawValue: String)
  /// 구독을 시작하면 현재 화면 모드를 즉시 한 번 방출하고, 이후 변경될 때마다 최신값을 방출한다.
  func appearanceStream() -> AsyncStream<String>

  // MARK: - Security

  func isRequireAuthOnLaunchEnabled() -> Bool
  func setRequireAuthOnLaunchEnabled(_ enabled: Bool)

  func isRequireAuthToCopyEnabled() -> Bool
  func setRequireAuthToCopyEnabled(_ enabled: Bool)

  func isAutoLockEnabled() -> Bool
  func setAutoLockEnabled(_ enabled: Bool)

  func autoLockMinutes() -> Int
  func setAutoLockMinutes(_ minutes: Int)

  /// 현재 자동 잠금 설정을 즉시 방출하고, 이후 설정이 바뀔 때마다 최신 구성을 방출한다.
  func autoLockConfigurationStream() -> AsyncStream<AutoLockConfiguration>

  func isAutoClearClipboardEnabled() -> Bool
  func setAutoClearClipboardEnabled(_ enabled: Bool)

  func autoClearClipboardDelaySeconds() -> Int
  func setAutoClearClipboardDelaySeconds(_ seconds: Int)

  func isWindowCaptureProtectionEnabled() -> Bool
  func setWindowCaptureProtectionEnabled(_ enabled: Bool)

  /// 구독을 시작하면 현재 설정값을 즉시 한 번 방출하고, 이후 설정이 변경될 때마다 최신값을 방출한다.
  func windowCaptureProtectionEnabledStream() -> AsyncStream<Bool>

  // MARK: - Notifications

  func isExpiryAlertsEnabled() -> Bool
  func setExpiryAlertsEnabled(_ enabled: Bool)

  func expiryAlertDaysBefore() -> [ExpiryAlertDay]
  func setExpiryAlertDaysBefore(_ days: [ExpiryAlertDay])
  /// 구독을 시작하면 현재 시점 목록을 즉시 한 번 방출하고, 이후 저장값이 바뀔 때마다 최신값을 방출한다.
  func expiryAlertDaysBeforeStream() -> AsyncStream<[ExpiryAlertDay]>

  func isAuthFailureAlertEnabled() -> Bool
  func setAuthFailureAlertEnabled(_ enabled: Bool)

  func isClipboardAbnormalAccessAlertEnabled() -> Bool
  func setClipboardAbnormalAccessAlertEnabled(_ enabled: Bool)

  // MARK: - Entitlement

  /// 마지막으로 확인된 기능 등급을 반환한다. 확인한 적이 없으면 `.free`.
  ///
  /// **StoreKit 조회 결과를 담아두는 캐시다.** `Transaction.currentEntitlements`는 비동기라 앱 시작 직후에는 답을 모르는데, 게이트 판정은 동기로 답해야 한다. 캐시가 없으면 그 구간에 Pro 사용자가 무료로 취급되어 **수정 화면이 잠긴다** — 정확히 결제한 사용자가 겪는 오작동이다. 스토어 확인이 끝나면 곧바로 정정된다.
  ///
  /// 기기별 캐시이므로 iCloud로 동기화하지 않는다. 권한의 진실은 언제나 Apple ID에 묶인 StoreKit이다.
  func cachedEntitlement() -> Entitlement
  func setCachedEntitlement(_ entitlement: Entitlement)

  /// 구독을 시작하면 현재 캐시값을 즉시 한 번 방출하고, 이후 캐시가 바뀔 때마다 최신값을 방출한다.
  func cachedEntitlementStream() -> AsyncStream<Entitlement>

  /// 마지막으로 확인된 구독 상태(상품·갱신일·자동 갱신 여부)를 반환한다. 확인한 적이 없으면 `.free`.
  ///
  /// **구매 직후 `Transaction.currentEntitlements`를 곧바로 재조회하면 스토어 반영 지연으로
  /// 갱신일이 잠깐 비어 있을 수 있다.** `PurchaseService`가 구매/복원에 성공한 순간 이미 손에 쥔
  /// 트랜잭션 정보를 여기 저장해 두면, 재조회 없이도 즉시 정확한 값을 돌려줄 수 있다.
  func cachedSubscriptionStatus() -> SubscriptionStatus
  func setCachedSubscriptionStatus(_ status: SubscriptionStatus)
}
