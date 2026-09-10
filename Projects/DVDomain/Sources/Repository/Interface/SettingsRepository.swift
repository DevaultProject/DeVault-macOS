// Copyright © 2026 Devault. All rights reserved

import Foundation

public protocol SettingsRepository: Sendable {
  // MARK: - Onboarding

  /// 온보딩을 완료했는지 확인한다.
  /// - Returns: 온보딩 완료 여부
  func hasCompletedOnboarding() -> Bool
  /// 온보딩 완료 상태를 저장한다.
  func setOnboardingCompleted()

  // MARK: - iCloud

  /// iCloud 동기화 사용 여부를 확인한다.
  /// - Returns: iCloud 동기화 사용 여부
  func isICloudSyncEnabled() -> Bool
  /// iCloud 동기화 사용 여부를 저장한다.
  /// - Parameter enabled: 사용 여부
  func setICloudSyncEnabled(_ enabled: Bool)

  /// 마지막으로 CloudKit 원격 변경이 감지된 시각. 한 번도 없었으면 nil.
  /// - Returns: 마지막 원격 변경 감지 시각. 기록이 없으면 nil
  func iCloudLastUpdateDetectedAt() -> Date?
  /// 마지막 CloudKit 원격 변경 감지 시각을 저장한다.
  /// - Parameter date: 저장할 원격 변경 감지 시각
  func setICloudLastUpdateDetectedAt(_ date: Date)

  // MARK: - General

  /// 로그인 시 자동 실행 여부를 확인한다.
  /// - Returns: 로그인 시 자동 실행 여부
  func isLaunchAtLoginEnabled() -> Bool
  /// 로그인 시 자동 실행 여부를 저장한다.
  /// - Parameter enabled: 로그인 시 자동 실행 여부
  func setLaunchAtLoginEnabled(_ enabled: Bool)

  /// 새 Secret 생성 시 자동 적용되는 기본 환경(rawValue).
  /// - Returns: 기본 환경의 rawValue
  func defaultEnvironment() -> String
  /// 새 Secret 생성 시 적용할 기본 환경(rawValue)을 저장한다.
  /// - Parameter rawValue: 저장할 기본 환경의 rawValue
  func setDefaultEnvironment(_ rawValue: String)

  /// 앱 전체에 적용할 화면 모드(rawValue: system/light/dark).
  /// - Returns: 화면 모드의 rawValue
  func appearance() -> String
  /// 앱 전체에 적용할 화면 모드(rawValue)를 저장한다.
  /// - Parameter rawValue: 저장할 화면 모드의 rawValue
  func setAppearance(_ rawValue: String)
  /// 구독을 시작하면 현재 화면 모드를 즉시 한 번 방출하고, 이후 변경될 때마다 최신값을 방출한다.
  /// - Returns: 앱 화면 모드 스트림
  func appearanceStream() -> AsyncStream<String>

  // MARK: - Security

  /// 앱 실행 시 인증 요구 여부.
  /// - Returns: 앱 실행 시 인증 요구 여부
  func isRequireAuthOnLaunchEnabled() -> Bool
  /// 앱 실행 시 인증 요구 여부를 저장한다.
  /// - Parameter enabled: 앱 실행 시 인증 요구 여부
  func setRequireAuthOnLaunchEnabled(_ enabled: Bool)

  /// Secret 값 복사 시 인증 요구 여부.
  /// - Returns: Secret 값 복사 시 인증 요구 여부
  func isRequireAuthToCopyEnabled() -> Bool
  /// Secret 값 복사 시 인증 요구 여부를 저장한다.
  /// - Parameter enabled: Secret 값 복사 시 인증 요구 여부
  func setRequireAuthToCopyEnabled(_ enabled: Bool)

  /// 비활성 후 자동 잠금 사용 여부.
  /// - Returns: 자동 잠금 사용 여부
  func isAutoLockEnabled() -> Bool
  /// 비활성 후 자동 잠금 사용 여부를 저장한다.
  /// - Parameter enabled: 자동 잠금 사용 여부
  func setAutoLockEnabled(_ enabled: Bool)

  /// 비활성 후 자동 잠금까지의 시간(분).
  /// - Returns: 자동 잠금까지의 시간(분)
  func autoLockMinutes() -> Int
  /// 비활성 후 자동 잠금까지의 시간(분)을 저장한다.
  /// - Parameter minutes: 저장할 자동 잠금 시간(분)
  func setAutoLockMinutes(_ minutes: Int)

  /// 현재 자동 잠금 설정을 즉시 방출하고, 이후 설정이 바뀔 때마다 최신 구성을 방출한다.
  /// - Returns: 자동 잠금 설정 스트림
  func autoLockConfigurationStream() -> AsyncStream<AutoLockConfiguration>

  /// 클립보드 자동 비우기 사용 여부.
  /// - Returns: 클립보드 자동 비우기 사용 여부
  func isAutoClearClipboardEnabled() -> Bool
  /// 클립보드 자동 비우기 사용 여부를 저장한다.
  /// - Parameter enabled: 클립보드 자동 비우기 사용 여부
  func setAutoClearClipboardEnabled(_ enabled: Bool)

  /// 클립보드 자동 비우기까지의 시간(초).
  /// - Returns: 클립보드 자동 비우기까지의 시간(초)
  func autoClearClipboardDelaySeconds() -> Int
  /// 클립보드 자동 비우기까지의 시간(초)을 저장한다.
  /// - Parameter seconds: 저장할 클립보드 자동 비우기 시간(초)
  func setAutoClearClipboardDelaySeconds(_ seconds: Int)

  /// 앱 창 전체의 캡처 보호 여부.
  /// - Returns: 앱 창 전체의 캡처 보호 여부
  func isWindowCaptureProtectionEnabled() -> Bool
  /// 앱 창 전체의 캡처 보호 여부를 저장한다.
  /// - Parameter enabled: 앱 창 전체의 캡처 보호 여부
  func setWindowCaptureProtectionEnabled(_ enabled: Bool)

  /// 구독을 시작하면 현재 설정값을 즉시 한 번 방출하고, 이후 설정이 변경될 때마다 최신값을 방출한다.
  /// - Returns: 앱 창 전체의 캡처 보호 설정 스트림
  func windowCaptureProtectionEnabledStream() -> AsyncStream<Bool>

  // MARK: - Notifications

  /// 만료 알림 사용 여부.
  /// - Returns: 만료 알림 사용 여부
  func isExpiryAlertsEnabled() -> Bool
  /// 만료 알림 사용 여부를 저장한다.
  /// - Parameter enabled: 만료 알림 사용 여부
  func setExpiryAlertsEnabled(_ enabled: Bool)

  /// 선택된 만료 알림 발송 시점을 반환한다.
  /// - Returns: 만료 알림 발송 시점 목록
  func expiryAlertDaysBefore() -> [ExpiryAlertDay]
  /// 만료 알림 발송 시점을 저장한다.
  /// - Parameter days: 저장할 만료 알림 발송 시점 목록
  func setExpiryAlertDaysBefore(_ days: [ExpiryAlertDay])
  /// 구독을 시작하면 현재 시점 목록을 즉시 한 번 방출하고, 이후 저장값이 바뀔 때마다 최신값을 방출한다.
  /// - Returns: 만료 알림 발송 시점 스트림
  func expiryAlertDaysBeforeStream() -> AsyncStream<[ExpiryAlertDay]>

  /// 반복 인증 실패 알림 사용 여부.
  /// - Returns: 반복 인증 실패 알림 사용 여부
  func isAuthFailureAlertEnabled() -> Bool
  /// 반복 인증 실패 알림 사용 여부를 저장한다.
  /// - Parameter enabled: 반복 인증 실패 알림 사용 여부
  func setAuthFailureAlertEnabled(_ enabled: Bool)

  /// 클립보드 반복 복사(비정상 접근) 알림 사용 여부.
  /// - Returns: 클립보드 반복 복사 알림 사용 여부
  func isClipboardAbnormalAccessAlertEnabled() -> Bool
  /// 클립보드 반복 복사 알림 사용 여부를 저장한다.
  /// - Parameter enabled: 클립보드 반복 복사 알림 사용 여부
  func setClipboardAbnormalAccessAlertEnabled(_ enabled: Bool)

  // MARK: - Entitlement

  /// 마지막으로 확인된 기능 등급을 반환한다.
  ///
  /// **StoreKit 조회 결과를 담아두는 캐시다.** `Transaction.currentEntitlements`는 비동기라 앱 시작 직후에는 답을 모르는데, 게이트 판정은 동기로 답해야 한다. 캐시가 없으면 그 구간에 Pro 사용자가 무료로 취급되어 **수정 화면이 잠긴다** — 정확히 결제한 사용자가 겪는 오작동이다. 스토어 확인이 끝나면 곧바로 정정된다.
  ///
  /// 기기별 캐시이므로 iCloud로 동기화하지 않는다. 권한의 진실은 언제나 Apple ID에 묶인 StoreKit이다.
  /// - Returns: 마지막으로 확인된 등급. 확인한 적이 없으면 `.free`
  func cachedEntitlement() -> Entitlement
  /// 확인된 기능 등급을 캐시에 저장한다.
  /// - Parameter entitlement: 저장할 등급
  func setCachedEntitlement(_ entitlement: Entitlement)

  /// 구독을 시작하면 현재 캐시값을 즉시 한 번 방출하고, 이후 캐시가 바뀔 때마다 최신값을 방출한다.
  /// - Returns: 등급 스트림
  func cachedEntitlementStream() -> AsyncStream<Entitlement>

  /// 마지막으로 확인된 구독 상태(상품·갱신일·자동 갱신 여부)를 반환한다.
  ///
  /// **구매 직후 `Transaction.currentEntitlements`를 곧바로 재조회하면 스토어 반영 지연으로
  /// 갱신일이 잠깐 비어 있을 수 있다.** `PurchaseService`가 구매/복원에 성공한 순간 이미 손에 쥔
  /// 트랜잭션 정보를 여기 저장해 두면, 재조회 없이도 즉시 정확한 값을 돌려줄 수 있다.
  /// - Returns: 마지막으로 확인된 구독 상태. 확인한 적이 없으면 `.free`
  func cachedSubscriptionStatus() -> SubscriptionStatus
  /// 확인된 구독 상태를 캐시에 저장한다.
  /// - Parameter status: 저장할 구독 상태
  func setCachedSubscriptionStatus(_ status: SubscriptionStatus)
}
