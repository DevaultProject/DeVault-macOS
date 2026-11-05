// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture

@DependencyClient
public struct WindowClient: Sendable {
  public var ensureMainWindowOpen: @Sendable () async -> Void = {}
  public var isMainWindowVisible: @Sendable () -> Bool = { true }
  /// 이미 떠 있는 창을 앞으로 가져온다 — `ensureMainWindowOpen`과 달리 `openWindow`를 부르지 않아 창을 재생성하지 않는다.
  public var activateMainWindow: @Sendable () async -> Void = {}
}

extension WindowClient: TestDependencyKey {
  public static let testValue = WindowClient()
  public static let previewValue = WindowClient()
}

extension DependencyValues {
  public var windowClient: WindowClient {
    get { self[WindowClient.self] }
    set { self[WindowClient.self] = newValue }
  }
}
