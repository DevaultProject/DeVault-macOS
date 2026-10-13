// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture

@DependencyClient
public struct AppSecurityClient: Sendable {
  /// 앱 실행 시 인증 요구 여부.
  public var isRequireAuthOnLaunchEnabled: @Sendable () -> Bool = { true }
  /// 설정된 비활성 시간이 지날 때마다 값을 방출한다.
  public var inactivityTimeoutStream: @Sendable () -> AsyncStream<Void> = {
    AsyncStream { $0.finish() }
  }
}

extension AppSecurityClient: TestDependencyKey {
  public static let testValue = AppSecurityClient()
  public static let previewValue = AppSecurityClient()
}

extension DependencyValues {
  public var appSecurityClient: AppSecurityClient {
    get { self[AppSecurityClient.self] }
    set { self[AppSecurityClient.self] = newValue }
  }
}
