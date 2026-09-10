// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct NotificationSettingsUseCaseImpl: NotificationSettingsUseCase {

  private let repository: any SettingsRepository
  private let expiryNotificationScheduler: any ScheduleSecretExpiryNotificationsUseCase
  private let entitlementUseCase: any EntitlementUseCase

  /// - Parameters:
  ///   - repository: 설정 저장소
  ///   - expiryNotificationScheduler: 설정 변경 후 예약 동기화
  ///   - entitlementUseCase: 다중 시점(Pro) 게이트 판정. 기본값 없이 필수 주입 — 빠지면 게이트가 조용히 뚫린다.
  public init(
    repository: any SettingsRepository,
    expiryNotificationScheduler: any ScheduleSecretExpiryNotificationsUseCase,
    entitlementUseCase: any EntitlementUseCase
  ) {
    self.repository = repository
    self.expiryNotificationScheduler = expiryNotificationScheduler
    self.entitlementUseCase = entitlementUseCase
  }

  public func isExpiryAlertsEnabled() -> Bool {
    repository.isExpiryAlertsEnabled()
  }

  public func setExpiryAlertsEnabled(_ enabled: Bool) async throws {
    repository.setExpiryAlertsEnabled(enabled)
    try await expiryNotificationScheduler.syncAll()
  }

  public func expiryAlertDaysBefore() -> [ExpiryAlertDay] {
    repository.expiryAlertDaysBefore()
  }

  public func setExpiryAlertDaysBefore(_ days: [ExpiryAlertDay]) async throws {
    // 막는 것은 "늘리기"뿐 — 줄이는 저장은 아직 한도를 넘어도 통과시킨다(강등 후 3→2처럼 한도로 다가가는 정상 동작). 막으면 UI와 저장소가 어긋난다.
    let previous = repository.expiryAlertDaysBefore().count
    if days.count > EntitlementLimits.maxExpiryAlertDays,
       days.count > previous,
       !entitlementUseCase.canUseMultipleExpiryAlertDays() {
      throw EntitlementError.requiresPro
    }
    repository.setExpiryAlertDaysBefore(days)
    try await expiryNotificationScheduler.syncAll()
  }

  public func resetExpiryAlertDaysForCurrentEntitlement() {
    if entitlementUseCase.canUseMultipleExpiryAlertDays() {
      repository.setExpiryAlertDaysBefore(ExpiryAlertDay.defaultSelection)
    } else {
      // 가장 이른 시점 하나만 남긴다(rawValue가 클수록 이른 시점)
      let current = repository.expiryAlertDaysBefore()
      guard let earliest = current.max(by: { $0.rawValue < $1.rawValue }) else { return }
      repository.setExpiryAlertDaysBefore([earliest])
    }
  }

  public func expiryAlertDaysBeforeStream() -> AsyncStream<[ExpiryAlertDay]> {
    repository.expiryAlertDaysBeforeStream()
  }

  public func isAuthFailureAlertEnabled() -> Bool {
    repository.isAuthFailureAlertEnabled()
  }

  public func setAuthFailureAlertEnabled(_ enabled: Bool) {
    repository.setAuthFailureAlertEnabled(enabled)
  }

  public func isClipboardAbnormalAccessAlertEnabled() -> Bool {
    repository.isClipboardAbnormalAccessAlertEnabled()
  }

  public func setClipboardAbnormalAccessAlertEnabled(_ enabled: Bool) {
    repository.setClipboardAbnormalAccessAlertEnabled(enabled)
  }
}
