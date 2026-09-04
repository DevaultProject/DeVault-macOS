// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVCore
import DVData
import DVDomain
import DVPresentation

extension AppLaunchClient: @retroactive DependencyKey {
  public static let liveValue: AppLaunchClient = {
    let onboardingStatusUseCase: any OnboardingStatusUseCase = OnboardingStatusUseCaseImpl(
      repository: LiveRepositories.settings
    )
    let iCloudSettingsUseCase: any ICloudSettingsUseCase = ICloudSettingsUseCaseImpl(
      repository: LiveRepositories.settings,
      iCloudService: ICloudServiceImpl(
        containerIdentifier: ICloudContainer.identifier,
        storageConfigurator: { enabled in
          try await LiveRepositories.storage.configure(iCloudSyncEnabled: enabled)
        }
      ),
      entitlementUseCase: LiveUseCases.entitlement
    )

    return AppLaunchClient(
      hasCompletedOnboarding: {
        onboardingStatusUseCase.hasCompleted()
      },
      setOnboardingCompleted: {
        onboardingStatusUseCase.setCompleted()
      },
      requestNotificationAuthorization: {
        do {
          return try await LiveServices.securityNotification.requestAuthorization()
        } catch {
          Log.warn("알림 권한 요청 실패: \(error)", category: .notification)
          return false
        }
      },
      syncExpiryNotifications: {
        do {
          try await LiveUseCases.expirySchedule.syncAll()
        } catch {
          Log.warn("만료 알림 동기화 실패: \(error)", category: .notification)
        }
      },
      iCloudRemoteChangeStream: {
        iCloudSettingsUseCase.remoteChangeStream()
      },
      setICloudLastUpdateDetectedAt: { date in
        iCloudSettingsUseCase.setLastUpdateDetectedAt(date)
      },
      disableICloudSyncForDowngrade: {
        // free로 내려가면 동기화를 끈다. 로컬 데이터는 유지, CloudKit 미러링만 중단.
        guard iCloudSettingsUseCase.isEnabled() else { return }
        do {
          try await iCloudSettingsUseCase.setEnabled(false)
          Log.info("[iCloud] 등급 하락으로 동기화 자동 중단", category: .data)
        } catch {
          Log.warn("등급 하락 시 iCloud 동기화 중단 실패: \(error)", category: .data)
        }
      }
    )
  }()
}
