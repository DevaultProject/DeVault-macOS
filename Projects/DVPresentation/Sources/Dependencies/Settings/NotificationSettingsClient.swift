// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain

@DependencyClient
public struct NotificationSettingsClient: Sendable {
  /// 만료 알림 사용 여부.
  public var isExpiryAlertsEnabled: @Sendable () -> Bool = { true }
  /// 만료 알림 사용 여부를 저장한다.
  public var setExpiryAlertsEnabled: @Sendable (Bool) async throws -> Void

  /// 선택된 만료 알림 발송 시점.
  public var expiryAlertDaysBefore: @Sendable () -> [ExpiryAlertDay] = {
    ExpiryAlertDay.defaultSelection
  }
  /// 만료 알림 발송 시점을 저장한다.
  public var setExpiryAlertDaysBefore: @Sendable ([ExpiryAlertDay]) async throws -> Void
  /// 저장된 발송 시점 변경 스트림. 등급 전환 리셋 등 외부 변경도 화면에 그대로 반영된다.
  public var expiryAlertDaysBeforeStream: @Sendable () -> AsyncStream<[ExpiryAlertDay]> = {
    AsyncStream { $0.finish() }
  }

  /// 반복 인증 실패 알림 사용 여부.
  public var isAuthFailureAlertEnabled: @Sendable () -> Bool = { true }
  /// 반복 인증 실패 알림 사용 여부를 저장한다.
  public var setAuthFailureAlertEnabled: @Sendable (Bool) -> Void

  /// 클립보드 반복 복사(비정상 접근) 알림 사용 여부.
  public var isClipboardAbnormalAccessAlertEnabled: @Sendable () -> Bool = { true }
  /// 클립보드 반복 복사 알림 사용 여부를 저장한다.
  public var setClipboardAbnormalAccessAlertEnabled: @Sendable (Bool) -> Void

  /// macOS 알림 권한이 허용돼 있는지. 꺼져 있으면 위 설정을 켜도 실제로는 알림이 안 온다.
  public var isPermissionGranted: @Sendable () async -> Bool = { true }
  /// macOS 알림 설정 패널을 연다.
  public var openSystemSettings: @Sendable () -> Void
}

extension NotificationSettingsClient: TestDependencyKey {
  public static let testValue = NotificationSettingsClient()

  public static let previewValue = NotificationSettingsClient(
    isExpiryAlertsEnabled: { true },
    setExpiryAlertsEnabled: { _ in },
    expiryAlertDaysBefore: { ExpiryAlertDay.defaultSelection },
    setExpiryAlertDaysBefore: { _ in },
    expiryAlertDaysBeforeStream: { AsyncStream { $0.finish() } },
    isAuthFailureAlertEnabled: { true },
    setAuthFailureAlertEnabled: { _ in },
    isClipboardAbnormalAccessAlertEnabled: { true },
    setClipboardAbnormalAccessAlertEnabled: { _ in },
    isPermissionGranted: { true },
    openSystemSettings: { }
  )
}

extension DependencyValues {
  public var notificationSettingsClient: NotificationSettingsClient {
    get { self[NotificationSettingsClient.self] }
    set { self[NotificationSettingsClient.self] = newValue }
  }
}
