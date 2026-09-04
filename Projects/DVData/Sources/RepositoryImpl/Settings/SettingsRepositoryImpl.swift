// Copyright © 2026 Devault. All rights reserved

import Foundation
import DVDomain

// UserDefaults는 thread-safe하므로 @unchecked Sendable 허용
public struct SettingsRepositoryImpl: SettingsRepository, @unchecked Sendable {

  private let defaults: UserDefaults
  private let ubiquitousStore: NSUbiquitousKeyValueStore

  // TODO: SecretEnvironment를 DVDomain 공용 타입으로 이동하면 `.dev.rawValue`로 대체한다.
  private enum DefaultValue {
    static let environment = "dev"
    // AppAppearance.system.rawValue와 동일. 기본은 macOS 시스템 설정을 따른다.
    static let appearance = "system"
  }

  public init(
    defaults: UserDefaults = .standard,
    ubiquitousStore: NSUbiquitousKeyValueStore = .default
  ) {
    self.defaults = defaults
    self.ubiquitousStore = ubiquitousStore

    // 아직 사용자가 저장한 값이 없을 때 사용할 기본값
    defaults.register(defaults: [
      UserDefaultsKey.defaultEnvironment.rawValue: DefaultValue.environment,
      UserDefaultsKey.appearance.rawValue: DefaultValue.appearance,
      UserDefaultsKey.isRequireAuthOnLaunchEnabled.rawValue: true,
      UserDefaultsKey.isRequireAuthToCopyEnabled.rawValue: true,
      UserDefaultsKey.isAutoLockEnabled.rawValue: true,
      UserDefaultsKey.autoLockMinutes.rawValue: 5,
      UserDefaultsKey.isAutoClearClipboardEnabled.rawValue: true,
      UserDefaultsKey.autoClearClipboardDelaySeconds.rawValue: 30,
      UserDefaultsKey.isWindowCaptureProtectionEnabled.rawValue: true,
      UserDefaultsKey.isExpiryAlertsEnabled.rawValue: true,
      UserDefaultsKey.isAuthFailureAlertEnabled.rawValue: true,
      UserDefaultsKey.isClipboardAbnormalAccessAlertEnabled.rawValue: true,
    ])
  }

  // MARK: - Onboarding

  // hasCompletedOnboarding은 기기별로 Touch ID 확인이 필요하므로 로컬 UserDefaults로 관리
  public func hasCompletedOnboarding() -> Bool {
    defaults.bool(forKey: .hasCompletedOnboarding)
  }

  public func setOnboardingCompleted() {
    defaults.set(true, forKey: .hasCompletedOnboarding)
  }

  // MARK: - iCloud

  // iCloud 동기화 사용 여부는 독립적으로 켜야 하므로 로컬 UserDefaults로 관리
  public func isICloudSyncEnabled() -> Bool {
    defaults.bool(forKey: .isICloudSyncEnabled)
  }

  public func setICloudSyncEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: .isICloudSyncEnabled)
  }

  public func iCloudLastUpdateDetectedAt() -> Date? {
    defaults.date(forKey: .iCloudLastUpdateDetectedAt)
  }

  public func setICloudLastUpdateDetectedAt(_ date: Date) {
    defaults.set(date, forKey: .iCloudLastUpdateDetectedAt)
  }

  // MARK: - General

  public func isLaunchAtLoginEnabled() -> Bool {
    defaults.bool(forKey: .isLaunchAtLoginEnabled)
  }

  public func setLaunchAtLoginEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: .isLaunchAtLoginEnabled)
  }

  public func defaultEnvironment() -> String {
    defaults.string(forKey: .defaultEnvironment) ?? DefaultValue.environment
  }

  public func setDefaultEnvironment(_ rawValue: String) {
    defaults.set(rawValue, forKey: .defaultEnvironment)
  }

  public func appearance() -> String {
    defaults.string(forKey: .appearance) ?? DefaultValue.appearance
  }

  public func setAppearance(_ rawValue: String) {
    defaults.set(rawValue, forKey: .appearance)
  }

  public func appearanceStream() -> AsyncStream<String> {
    defaultsStream(appearance)
  }

  /// UserDefaults 변경을 구독해 `read()` 결과를 방출한다. 구독 즉시 현재값을 한 번 내보낸다.
  ///
  /// `didChangeNotification`은 **suite 안의 아무 키가 바뀌어도** 오므로, 값이 실제로 달라졌을 때만 방출한다. 그렇지 않으면 자동 잠금 시간을 바꿔도 등급이 바뀐 것처럼 보여 구독자가 헛일을 한다.
  private func defaultsStream<Value: Equatable & Sendable>(
    _ read: @escaping @Sendable () -> Value
  ) -> AsyncStream<Value> {
    AsyncStream { continuation in
      let state = LastValueBox<Value>()

      // 최초 방출보다 **먼저** 건다. 뒤에 걸면 그 사이에 일어난 변경의 알림을 놓친다.
      let observer = NotificationCenter.default.addObserver(
        forName: UserDefaults.didChangeNotification,
        object: defaults,
        queue: nil
      ) { _ in
        state.emitIfChanged(read: read) { continuation.yield($0) }
      }

      continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(observer)
      }

      state.emitIfChanged(read: read) { continuation.yield($0) }
    }
  }

  // MARK: - Entitlement

  public func cachedEntitlement() -> Entitlement {
    defaults.string(forKey: .cachedEntitlement)
      .flatMap(Entitlement.init(rawValue:)) ?? .free
  }

  public func setCachedEntitlement(_ entitlement: Entitlement) {
    defaults.set(entitlement.rawValue, forKey: .cachedEntitlement)
  }

  public func cachedEntitlementStream() -> AsyncStream<Entitlement> {
    defaultsStream(cachedEntitlement)
  }

  public func cachedSubscriptionStatus() -> SubscriptionStatus {
    SubscriptionStatus(
      entitlement: cachedEntitlement(),
      productID: defaults.string(forKey: .cachedSubscriptionProductID),
      renewsAt: defaults.date(forKey: .cachedSubscriptionRenewsAt),
      willAutoRenew: defaults.bool(forKey: .cachedSubscriptionWillAutoRenew),
      renewalProductID: defaults.string(forKey: .cachedSubscriptionRenewalProductID)
    )
  }

  public func setCachedSubscriptionStatus(_ status: SubscriptionStatus) {
    // 등급 자체는 setCachedEntitlement가 별도로 관리한다 — 여기서는 상품·갱신일·자동 갱신 여부만 저장한다.
    if let productID = status.productID {
      defaults.set(productID, forKey: .cachedSubscriptionProductID)
    } else {
      defaults.removeObject(forKey: .cachedSubscriptionProductID)
    }
    if let renewsAt = status.renewsAt {
      defaults.set(renewsAt, forKey: .cachedSubscriptionRenewsAt)
    } else {
      defaults.removeObject(forKey: .cachedSubscriptionRenewsAt)
    }
    defaults.set(status.willAutoRenew, forKey: .cachedSubscriptionWillAutoRenew)
    if let renewalProductID = status.renewalProductID {
      defaults.set(renewalProductID, forKey: .cachedSubscriptionRenewalProductID)
    } else {
      defaults.removeObject(forKey: .cachedSubscriptionRenewalProductID)
    }
  }

  // MARK: - Security

  public func isRequireAuthOnLaunchEnabled() -> Bool {
    defaults.bool(forKey: .isRequireAuthOnLaunchEnabled)
  }

  public func setRequireAuthOnLaunchEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: .isRequireAuthOnLaunchEnabled)
  }

  public func isRequireAuthToCopyEnabled() -> Bool {
    defaults.bool(forKey: .isRequireAuthToCopyEnabled)
  }

  public func setRequireAuthToCopyEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: .isRequireAuthToCopyEnabled)
  }

  public func isAutoLockEnabled() -> Bool {
    defaults.bool(forKey: .isAutoLockEnabled)
  }

  public func setAutoLockEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: .isAutoLockEnabled)
  }

  public func autoLockMinutes() -> Int {
    defaults.integer(forKey: .autoLockMinutes)
  }

  public func setAutoLockMinutes(_ minutes: Int) {
    defaults.set(minutes, forKey: .autoLockMinutes)
  }

  public func autoLockConfigurationStream() -> AsyncStream<AutoLockConfiguration> {
    AsyncStream { continuation in
      let observer = NotificationCenter.default.addObserver(
        forName: UserDefaults.didChangeNotification,
        object: defaults,
        queue: nil
      ) { _ in
        continuation.yield(autoLockConfiguration())
      }

      continuation.yield(autoLockConfiguration())
      continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(observer)
      }
    }
  }

  public func isAutoClearClipboardEnabled() -> Bool {
    defaults.bool(forKey: .isAutoClearClipboardEnabled)
  }

  public func setAutoClearClipboardEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: .isAutoClearClipboardEnabled)
  }

  public func autoClearClipboardDelaySeconds() -> Int {
    defaults.integer(forKey: .autoClearClipboardDelaySeconds)
  }

  public func setAutoClearClipboardDelaySeconds(_ seconds: Int) {
    defaults.set(seconds, forKey: .autoClearClipboardDelaySeconds)
  }

  public func isWindowCaptureProtectionEnabled() -> Bool {
    defaults.bool(forKey: .isWindowCaptureProtectionEnabled)
  }

  public func setWindowCaptureProtectionEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: .isWindowCaptureProtectionEnabled)
  }

  public func windowCaptureProtectionEnabledStream() -> AsyncStream<Bool> {
    AsyncStream { continuation in
      let observer = NotificationCenter.default.addObserver(
        forName: UserDefaults.didChangeNotification,
        object: defaults,
        queue: nil
      ) { _ in
        continuation.yield(isWindowCaptureProtectionEnabled())
      }

      continuation.yield(isWindowCaptureProtectionEnabled())
      continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(observer)
      }
    }
  }

  // MARK: - Notifications

  public func isExpiryAlertsEnabled() -> Bool {
    defaults.bool(forKey: .isExpiryAlertsEnabled)
  }

  public func setExpiryAlertsEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: .isExpiryAlertsEnabled)
  }

  public func expiryAlertDaysBefore() -> [ExpiryAlertDay] {
    guard let rawValues = defaults.integerArray(forKey: .expiryAlertDaysBefore) else {
      // 저장된 적이 한 번도 없을 때만 등급을 보고 기본값을 정한다. 이후 실제로 저장된 값은
      // 등급이 바뀌어도 절대 여기서 건드리지 않는다 — 다운그레이드 시 재구독 복원을 위해서다.
      // 무료 기본값은 임의의 요일이 아니라, 여러 개 중 하나만 남길 때와 같은 기준(가장 이른 시점 =
      // 대응할 시간을 가장 많이 준다, `ScheduleSecretExpiryNotificationsUseCaseImpl` 참고)을 그대로 쓴다.
      return cachedEntitlement() == .pro ? ExpiryAlertDay.defaultSelection : [.thirtyDaysBefore]
    }
    return rawValues.compactMap(ExpiryAlertDay.init(rawValue:))
  }

  public func setExpiryAlertDaysBefore(_ days: [ExpiryAlertDay]) {
    defaults.set(days.map(\.rawValue), forKey: .expiryAlertDaysBefore)
  }

  public func isAuthFailureAlertEnabled() -> Bool {
    defaults.bool(forKey: .isAuthFailureAlertEnabled)
  }

  public func setAuthFailureAlertEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: .isAuthFailureAlertEnabled)
  }

  public func isClipboardAbnormalAccessAlertEnabled() -> Bool {
    defaults.bool(forKey: .isClipboardAbnormalAccessAlertEnabled)
  }

  public func setClipboardAbnormalAccessAlertEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: .isClipboardAbnormalAccessAlertEnabled)
  }

  private func autoLockConfiguration() -> AutoLockConfiguration {
    AutoLockConfiguration(
      isEnabled: isAutoLockEnabled(),
      timeout: .seconds(autoLockMinutes() * 60)
    )
  }
}

/// 마지막으로 방출한 값을 붙들어 두는 상자. 알림 콜백이 어느 큐에서 오든 안전하도록 락으로 감싼다.
private final class LastValueBox<Value: Equatable>: @unchecked Sendable {

  private let lock = NSLock()
  /// 아직 아무것도 내보내지 않은 상태를 `nil`로 구분한다. 첫 호출은 값이 무엇이든 방출된다.
  private var storage: Value?

  /// **읽기·비교·방출을 한 임계 구역에서 처리한다.** 읽기를 밖에 두면 오래된 값이 비교를 통과해 최신값 뒤에 방출될 수 있다 — 구매 직후 구독자가 잠시 무료로 되돌아간다.
  /// - Parameters:
  ///   - read: 현재값을 읽는 클로저
  ///   - yield: 값이 달라졌을 때 방출할 클로저
  func emitIfChanged(read: () -> Value, yield: (Value) -> Void) {
    lock.withLock {
      let next = read()
      guard storage != next else { return }
      storage = next
      yield(next)
    }
  }
}
