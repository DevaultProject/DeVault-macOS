// Copyright © 2026 Devault. All rights reserved

import AppKit
import UserNotifications

import ComposableArchitecture
import DVDomain
import DVPresentation

extension NotificationSettingsClient: @retroactive DependencyKey {
  public static let liveValue: NotificationSettingsClient = {
    let useCase = LiveUseCases.notificationSettings

    return NotificationSettingsClient(
      isExpiryAlertsEnabled: {
        useCase.isExpiryAlertsEnabled()
      },
      setExpiryAlertsEnabled: { enabled in
        try await useCase.setExpiryAlertsEnabled(enabled)
      },
      expiryAlertDaysBefore: {
        useCase.expiryAlertDaysBefore()
      },
      setExpiryAlertDaysBefore: { days in
        try await useCase.setExpiryAlertDaysBefore(days)
      },
      expiryAlertDaysBeforeStream: {
        useCase.expiryAlertDaysBeforeStream()
      },
      isAuthFailureAlertEnabled: {
        useCase.isAuthFailureAlertEnabled()
      },
      setAuthFailureAlertEnabled: { enabled in
        useCase.setAuthFailureAlertEnabled(enabled)
      },
      isClipboardAbnormalAccessAlertEnabled: {
        useCase.isClipboardAbnormalAccessAlertEnabled()
      },
      setClipboardAbnormalAccessAlertEnabled: { enabled in
        useCase.setClipboardAbnormalAccessAlertEnabled(enabled)
      },
      isPermissionGranted: {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
      },
      openSystemSettings: {
        guard let url = URL(
          string: "x-apple.systempreferences:com.apple.preference.notifications"
        ) else { return }
        NSWorkspace.shared.open(url)
      }
    )
  }()
}
