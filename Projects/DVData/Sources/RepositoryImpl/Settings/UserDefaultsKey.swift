// Copyright © 2026 Devault. All rights reserved

import Foundation

enum UserDefaultsKey: String {
  case hasCompletedOnboarding

  // iCloud
  case isICloudSyncEnabled
  case iCloudLastUpdateDetectedAt

  // General
  case isLaunchAtLoginEnabled
  case defaultEnvironment
  case appearance

  // Security
  case isRequireAuthOnLaunchEnabled
  case isRequireAuthToCopyEnabled
  case isAutoLockEnabled
  case autoLockMinutes
  case isAutoClearClipboardEnabled
  case autoClearClipboardDelaySeconds
  case isWindowCaptureProtectionEnabled

  // Notifications
  case isExpiryAlertsEnabled
  case expiryAlertDaysBefore
  case isAuthFailureAlertEnabled
  case isClipboardAbnormalAccessAlertEnabled

  // Entitlement
  case cachedEntitlement

  // Subscription status
  case cachedSubscriptionProductID
  case cachedSubscriptionRenewsAt
  case cachedSubscriptionWillAutoRenew
  case cachedSubscriptionRenewalProductID
}

extension UserDefaults {
  func bool(forKey key: UserDefaultsKey) -> Bool {
    bool(forKey: key.rawValue)
  }

  func set(_ value: Bool, forKey key: UserDefaultsKey) {
    set(value, forKey: key.rawValue)
  }

  func integer(forKey key: UserDefaultsKey) -> Int {
    integer(forKey: key.rawValue)
  }

  func set(_ value: Int, forKey key: UserDefaultsKey) {
    set(value, forKey: key.rawValue)
  }

  func string(forKey key: UserDefaultsKey) -> String? {
    string(forKey: key.rawValue)
  }

  func set(_ value: String?, forKey key: UserDefaultsKey) {
    set(value, forKey: key.rawValue)
  }

  func integerArray(forKey key: UserDefaultsKey) -> [Int]? {
    array(forKey: key.rawValue) as? [Int]
  }

  func set(_ value: [Int], forKey key: UserDefaultsKey) {
    set(value, forKey: key.rawValue)
  }

  func date(forKey key: UserDefaultsKey) -> Date? {
    object(forKey: key.rawValue) as? Date
  }

  func set(_ value: Date, forKey key: UserDefaultsKey) {
    set(value, forKey: key.rawValue)
  }

  func removeObject(forKey key: UserDefaultsKey) {
    removeObject(forKey: key.rawValue)
  }
}
