// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVDomain

@DependencyClient
public struct GeneralSettingsClient: Sendable {
  /// 로그인 시 자동 실행 상태.
  public var launchAtLoginStatus: @Sendable () -> LaunchAtLoginStatus = { .notRegistered }
  /// 시스템 로그인 항목 변경에 성공한 뒤 설정을 저장한다. 실패하면 저장하지 않는다.
  public var setLaunchAtLoginEnabled: @Sendable (Bool) throws -> LaunchAtLoginStatus
  /// 시스템 로그인 항목 설정 패널을 연다.
  public var openLoginItemsSystemSettings: @Sendable () -> Void

  /// 새 Secret 생성 시 자동 적용되는 기본 환경(rawValue).
  public var defaultEnvironment: @Sendable () -> String = { "dev" }
  /// 새 Secret 생성 시 적용할 기본 환경(rawValue)을 저장한다.
  public var setDefaultEnvironment: @Sendable (String) -> Void

  /// 앱 전체에 적용할 화면 모드(rawValue: system/light/dark).
  public var appearance: @Sendable () -> String = { "system" }
  /// 앱 전체에 적용할 화면 모드(rawValue)를 저장한다.
  public var setAppearance: @Sendable (String) -> Void
  /// 구독을 시작하면 현재 화면 모드를 즉시 한 번 방출하고, 이후 변경될 때마다 최신값을 방출한다.
  public var appearanceStream: @Sendable () -> AsyncStream<String> = { AsyncStream { $0.finish() } }
}

extension GeneralSettingsClient: TestDependencyKey {
  public static let testValue = GeneralSettingsClient()

  public static let previewValue = GeneralSettingsClient(
    launchAtLoginStatus: { .notRegistered },
    setLaunchAtLoginEnabled: { _ in .notRegistered },
    openLoginItemsSystemSettings: { },
    defaultEnvironment: { "dev" },
    setDefaultEnvironment: { _ in },
    appearance: { "system" },
    setAppearance: { _ in },
    appearanceStream: { AsyncStream { $0.finish() } }
  )
}

extension DependencyValues {
  public var generalSettingsClient: GeneralSettingsClient {
    get { self[GeneralSettingsClient.self] }
    set { self[GeneralSettingsClient.self] = newValue }
  }
}
