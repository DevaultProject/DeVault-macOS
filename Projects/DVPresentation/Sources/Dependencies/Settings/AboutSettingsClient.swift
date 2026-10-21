// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture

@DependencyClient
public struct AboutSettingsClient: Sendable {
  /// 앱 버전 문자열.
  public var appVersion: @Sendable () -> String = { "-" }
}

extension AboutSettingsClient: TestDependencyKey {
  public static let testValue = AboutSettingsClient()
  public static let previewValue = AboutSettingsClient(
    appVersion: { "1.0.0" }
  )
}

extension DependencyValues {
  public var aboutSettingsClient: AboutSettingsClient {
    get { self[AboutSettingsClient.self] }
    set { self[AboutSettingsClient.self] = newValue }
  }
}
