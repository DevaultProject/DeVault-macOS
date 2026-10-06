// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain

/// 온보딩과 Settings의 iCloud 탭이 공유한다.
///
/// message/canRetry/canOpenSettings를 하나의 exhaustive switch로 묶어야 새 ICloudAccountStatus
/// 케이스 추가 시 컴파일러가 전부 재검토를 강제한다.
func makeICloudSyncUnavailableAlert<Alert: Equatable>(
  _ status: ICloudAccountStatus,
  retry: Alert,
  continueWithoutSync: Alert?,
  openSystemSettings: Alert
) -> AlertState<Alert> {
  if status == .available {
    assertionFailure("iCloudSyncStatusResponse가 이미 .available을 걸러내므로 도달 불가")
  }
  let (message, canRetry, canOpenSettings): (String, Bool, Bool) = switch status {
  case .available:
    (String.module("Please try again."), true, false)
  case .noAccount:
    (String.module("Sign in to iCloud in System Settings, then try again."), true, true)
  case .restricted:
    (String.module("Check your device's iCloud usage restrictions."), true, true)
  case .temporarilyUnavailable:
    (String.module("Please try again in a moment."), true, false)
  case .networkUnavailable:
    (String.module("Check your network connection and try again."), true, false)
  case .configurationUnavailable:
    // 앱 배포 설정(컨테이너 식별자, entitlement) 문제라 사용자가 재시도해도 해결되지 않음.
    (String.module("iCloud sync isn't available right now. Please try again later."), false, false)
  case .couldNotDetermine:
    (String.module("Couldn't determine iCloud status. Please try again in a moment."), true, false)
  }
  return AlertState {
    TextState(String.module("iCloud sync isn't available."))
  } actions: {
    if canRetry {
      ButtonState(action: retry) { TextState(String.module("Try Again")) }
    }
    if canOpenSettings {
      ButtonState(action: openSystemSettings) { TextState(String.module("Open System Settings")) }
    }
    if let continueWithoutSync {
      ButtonState(action: continueWithoutSync) { TextState(String.module("Continue Without iCloud")) }
    }
    ButtonState(role: .cancel) { TextState(String.module("OK")) }
  } message: {
    TextState(message)
  }
}
