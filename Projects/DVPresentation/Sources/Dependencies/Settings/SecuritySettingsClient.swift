// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture

@DependencyClient
public struct SecuritySettingsClient: Sendable {
  /// 앱 실행 시 인증 요구 여부.
  public var isRequireAuthOnLaunchEnabled: @Sendable () -> Bool = { true }
  /// 앱 실행 시 인증 요구 여부를 저장한다.
  public var setRequireAuthOnLaunchEnabled: @Sendable (Bool) -> Void

  /// Secret 값 복사 시 인증 요구 여부.
  public var isRequireAuthToCopyEnabled: @Sendable () -> Bool = { true }
  /// Secret 값 복사 시 인증 요구 여부를 저장한다.
  public var setRequireAuthToCopyEnabled: @Sendable (Bool) -> Void

  /// 비활성 후 자동 잠금 사용 여부.
  public var isAutoLockEnabled: @Sendable () -> Bool = { true }
  /// 비활성 후 자동 잠금 사용 여부를 저장한다.
  public var setAutoLockEnabled: @Sendable (Bool) -> Void

  /// 비활성 후 자동 잠금까지의 시간(분).
  public var autoLockMinutes: @Sendable () -> Int = { 5 }
  /// 비활성 후 자동 잠금까지의 시간(분)을 저장한다.
  public var setAutoLockMinutes: @Sendable (Int) -> Void

  /// 클립보드 자동 비우기 사용 여부.
  public var isAutoClearClipboardEnabled: @Sendable () -> Bool = { true }
  /// 클립보드 자동 비우기 사용 여부를 저장한다.
  public var setAutoClearClipboardEnabled: @Sendable (Bool) -> Void

  /// 클립보드 자동 비우기까지의 시간(초).
  public var autoClearClipboardDelaySeconds: @Sendable () -> Int = { 30 }
  /// 클립보드 자동 비우기까지의 시간(초)을 저장한다.
  public var setAutoClearClipboardDelaySeconds: @Sendable (Int) -> Void

  /// 앱 창 전체의 캡처 보호 여부.
  public var isWindowCaptureProtectionEnabled: @Sendable () -> Bool = { true }
  /// 앱 창 전체의 캡처 보호 여부를 저장한다.
  public var setWindowCaptureProtectionEnabled: @Sendable (Bool) -> Void
}

extension SecuritySettingsClient: TestDependencyKey {
  public static let testValue = SecuritySettingsClient()

  public static let previewValue = SecuritySettingsClient(
    isRequireAuthOnLaunchEnabled: { true },
    setRequireAuthOnLaunchEnabled: { _ in },
    isRequireAuthToCopyEnabled: { true },
    setRequireAuthToCopyEnabled: { _ in },
    isAutoLockEnabled: { true },
    setAutoLockEnabled: { _ in },
    autoLockMinutes: { 5 },
    setAutoLockMinutes: { _ in },
    isAutoClearClipboardEnabled: { true },
    setAutoClearClipboardEnabled: { _ in },
    autoClearClipboardDelaySeconds: { 30 },
    setAutoClearClipboardDelaySeconds: { _ in },
    isWindowCaptureProtectionEnabled: { true },
    setWindowCaptureProtectionEnabled: { _ in }
  )
}

extension DependencyValues {
  public var securitySettingsClient: SecuritySettingsClient {
    get { self[SecuritySettingsClient.self] }
    set { self[SecuritySettingsClient.self] = newValue }
  }
}
