// Copyright © 2026 Devault. All rights reserved

import Foundation

/// 보안 및 만료 알림 설정을 조회하고 변경합니다.
public protocol NotificationSettingsUseCase: Sendable {
  /// 만료 알림 사용 여부를 확인한다.
  /// - Returns: 만료 알림 사용 여부
  func isExpiryAlertsEnabled() -> Bool
  /// 만료 알림 사용 여부를 저장하고 기존 만료 알림 예약을 즉시 동기화한다.
  /// - Parameter enabled: 만료 알림 사용 여부
  func setExpiryAlertsEnabled(_ enabled: Bool) async throws

  /// 만료 알림을 보낼 시점을 반환한다.
  /// - Returns: 만료 알림 발송 시점 목록
  func expiryAlertDaysBefore() -> [ExpiryAlertDay]
  /// 만료 알림 발송 일수 목록을 저장하고 기존 만료 알림 예약을 즉시 동기화한다.
  /// - Parameter days: 저장할 만료 알림 발송 시점 목록
  func setExpiryAlertDaysBefore(_ days: [ExpiryAlertDay]) async throws

  /// 등급 전환 시 알림 시점을 등급 기본값으로 리셋한다(Pro=전체, Free=가장 이른 하나, 없으면 그대로).
  func resetExpiryAlertDaysForCurrentEntitlement()
  /// 만료 알림 발송 시점 변경을 구독한다(현재값 즉시 방출 후 바뀔 때마다).
  func expiryAlertDaysBeforeStream() -> AsyncStream<[ExpiryAlertDay]>

  /// 반복 인증 실패 알림 사용 여부를 확인한다.
  /// - Returns: 반복 인증 실패 알림 사용 여부
  func isAuthFailureAlertEnabled() -> Bool
  /// 반복 인증 실패 알림 사용 여부를 저장한다.
  /// - Parameter enabled: 반복 인증 실패 알림 사용 여부
  func setAuthFailureAlertEnabled(_ enabled: Bool)

  /// 클립보드 반복 복사 알림 사용 여부를 확인한다.
  /// - Returns: 클립보드 반복 복사 알림 사용 여부
  func isClipboardAbnormalAccessAlertEnabled() -> Bool
  /// 클립보드 반복 복사 알림 사용 여부를 저장한다.
  /// - Parameter enabled: 클립보드 반복 복사 알림 사용 여부
  func setClipboardAbnormalAccessAlertEnabled(_ enabled: Bool)
}
