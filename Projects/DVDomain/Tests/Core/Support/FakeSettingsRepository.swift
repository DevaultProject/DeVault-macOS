// Copyright © 2026 Devault. All rights reserved

import Foundation

@testable import DVDomain

/// 테스트용 SettingsRepository 구현. UserDefaults 없이 메모리에만 저장한다.
public final class FakeSettingsRepository: SettingsRepository, @unchecked Sendable {
    public var hasCompletedOnboardingValue = false
    public var isICloudSyncEnabledValue = false
    public var iCloudLastUpdateDetectedAtValue: Date?

    public var isLaunchAtLoginEnabledValue = false
    public var defaultEnvironmentValue = "dev"
    public var appearanceValue = "system"
    public var appearanceStreamValue: AsyncStream<String>?

    public var isRequireAuthOnLaunchEnabledValue = true
    public var isRequireAuthToCopyEnabledValue = true
    public var isAutoLockEnabledValue = true
    public var autoLockMinutesValue = 5
    public var autoLockConfigurationStreamValue: AsyncStream<AutoLockConfiguration>?
    public var isAutoClearClipboardEnabledValue = true
    public var autoClearClipboardDelaySecondsValue = 30
    public var isWindowCaptureProtectionEnabledValue = true
    public var windowCaptureProtectionEnabledStreamValue: AsyncStream<Bool>?

    public var isExpiryAlertsEnabledValue = true
    public var expiryAlertDaysBeforeValue = ExpiryAlertDay.defaultSelection
    public var expiryAlertDaysBeforeStreamValue: AsyncStream<[ExpiryAlertDay]>?
    public var isAuthFailureAlertEnabledValue = true
    public var isClipboardAbnormalAccessAlertEnabledValue = true

    public init() {}

    public func hasCompletedOnboarding() -> Bool { hasCompletedOnboardingValue }
    public func setOnboardingCompleted() { hasCompletedOnboardingValue = true }

    public func isICloudSyncEnabled() -> Bool { isICloudSyncEnabledValue }
    public func setICloudSyncEnabled(_ enabled: Bool) { isICloudSyncEnabledValue = enabled }

    public func iCloudLastUpdateDetectedAt() -> Date? { iCloudLastUpdateDetectedAtValue }
    public func setICloudLastUpdateDetectedAt(_ date: Date) { iCloudLastUpdateDetectedAtValue = date }

    public func isLaunchAtLoginEnabled() -> Bool { isLaunchAtLoginEnabledValue }
    public func setLaunchAtLoginEnabled(_ enabled: Bool) { isLaunchAtLoginEnabledValue = enabled }

    public func defaultEnvironment() -> String { defaultEnvironmentValue }
    public func setDefaultEnvironment(_ rawValue: String) { defaultEnvironmentValue = rawValue }

    public func appearance() -> String { appearanceValue }
    public func setAppearance(_ rawValue: String) { appearanceValue = rawValue }
    public func appearanceStream() -> AsyncStream<String> {
        if let appearanceStreamValue {
            return appearanceStreamValue
        }
        return AsyncStream { continuation in
            continuation.yield(appearanceValue)
            continuation.finish()
        }
    }

    public func isRequireAuthOnLaunchEnabled() -> Bool { isRequireAuthOnLaunchEnabledValue }
    public func setRequireAuthOnLaunchEnabled(_ enabled: Bool) { isRequireAuthOnLaunchEnabledValue = enabled }

    public func isRequireAuthToCopyEnabled() -> Bool { isRequireAuthToCopyEnabledValue }
    public func setRequireAuthToCopyEnabled(_ enabled: Bool) { isRequireAuthToCopyEnabledValue = enabled }

    public func isAutoLockEnabled() -> Bool { isAutoLockEnabledValue }
    public func setAutoLockEnabled(_ enabled: Bool) { isAutoLockEnabledValue = enabled }

    public func autoLockMinutes() -> Int { autoLockMinutesValue }
    public func setAutoLockMinutes(_ minutes: Int) { autoLockMinutesValue = minutes }
    public func autoLockConfigurationStream() -> AsyncStream<AutoLockConfiguration> {
        if let autoLockConfigurationStreamValue {
            return autoLockConfigurationStreamValue
        }
        let configuration = AutoLockConfiguration(
            isEnabled: isAutoLockEnabledValue,
            timeout: .seconds(autoLockMinutesValue * 60)
        )
        return AsyncStream { continuation in
            continuation.yield(configuration)
        }
    }

    public func isAutoClearClipboardEnabled() -> Bool { isAutoClearClipboardEnabledValue }
    public func setAutoClearClipboardEnabled(_ enabled: Bool) { isAutoClearClipboardEnabledValue = enabled }

    public func autoClearClipboardDelaySeconds() -> Int { autoClearClipboardDelaySecondsValue }
    public func setAutoClearClipboardDelaySeconds(_ seconds: Int) { autoClearClipboardDelaySecondsValue = seconds }

    public func isWindowCaptureProtectionEnabled() -> Bool { isWindowCaptureProtectionEnabledValue }
    public func setWindowCaptureProtectionEnabled(_ enabled: Bool) { isWindowCaptureProtectionEnabledValue = enabled }
    public func windowCaptureProtectionEnabledStream() -> AsyncStream<Bool> {
        if let windowCaptureProtectionEnabledStreamValue {
            return windowCaptureProtectionEnabledStreamValue
        }
        return AsyncStream { continuation in
            continuation.yield(isWindowCaptureProtectionEnabledValue)
            continuation.finish()
        }
    }

    public func isExpiryAlertsEnabled() -> Bool { isExpiryAlertsEnabledValue }
    public func setExpiryAlertsEnabled(_ enabled: Bool) { isExpiryAlertsEnabledValue = enabled }

    public func expiryAlertDaysBefore() -> [ExpiryAlertDay] { expiryAlertDaysBeforeValue }
    public func setExpiryAlertDaysBefore(_ days: [ExpiryAlertDay]) { expiryAlertDaysBeforeValue = days }
    public func expiryAlertDaysBeforeStream() -> AsyncStream<[ExpiryAlertDay]> {
        if let expiryAlertDaysBeforeStreamValue {
            return expiryAlertDaysBeforeStreamValue
        }
        return AsyncStream { continuation in
            continuation.yield(expiryAlertDaysBeforeValue)
            continuation.finish()
        }
    }

    public func isAuthFailureAlertEnabled() -> Bool { isAuthFailureAlertEnabledValue }
    public func setAuthFailureAlertEnabled(_ enabled: Bool) { isAuthFailureAlertEnabledValue = enabled }

    public func isClipboardAbnormalAccessAlertEnabled() -> Bool { isClipboardAbnormalAccessAlertEnabledValue }
    public func setClipboardAbnormalAccessAlertEnabled(_ enabled: Bool) { isClipboardAbnormalAccessAlertEnabledValue = enabled }

    public var cachedEntitlementValue: Entitlement = .free

    public func cachedEntitlement() -> Entitlement { cachedEntitlementValue }
    public func setCachedEntitlement(_ entitlement: Entitlement) { cachedEntitlementValue = entitlement }

    public func cachedEntitlementStream() -> AsyncStream<Entitlement> {
        AsyncStream { continuation in
            continuation.yield(cachedEntitlementValue)
            continuation.finish()
        }
    }

    public var cachedSubscriptionStatusValue = SubscriptionStatus.free

    public func cachedSubscriptionStatus() -> SubscriptionStatus { cachedSubscriptionStatusValue }
    public func setCachedSubscriptionStatus(_ status: SubscriptionStatus) { cachedSubscriptionStatusValue = status }
}
