// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain

@DependencyClient
public struct NotificationSettingsClient: Sendable {
  public var isExpiryAlertsEnabled: @Sendable () -> Bool = { true }
  public var setExpiryAlertsEnabled: @Sendable (Bool) async throws -> Void

  public var expiryAlertDaysBefore: @Sendable () -> [ExpiryAlertDay] = {
    ExpiryAlertDay.defaultSelection
  }
  public var setExpiryAlertDaysBefore: @Sendable ([ExpiryAlertDay]) async throws -> Void
  /// 저장된 발송 시점 변경 스트림. 등급 전환 리셋 등 외부 변경도 화면에 그대로 반영된다.
  public var expiryAlertDaysBeforeStream: @Sendable () -> AsyncStream<[ExpiryAlertDay]> = {
    AsyncStream { $0.finish() }
  }

  public var isAuthFailureAlertEnabled: @Sendable () -> Bool = { true }
  public var setAuthFailureAlertEnabled: @Sendable (Bool) -> Void

  public var isClipboardAbnormalAccessAlertEnabled: @Sendable () -> Bool = { true }
  public var setClipboardAbnormalAccessAlertEnabled: @Sendable (Bool) -> Void

  /// macOS 알림 권한이 허용돼 있는지. 꺼져 있으면 위 설정을 켜도 실제로는 알림이 안 온다.
  public var isPermissionGranted: @Sendable () async -> Bool = { true }
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
