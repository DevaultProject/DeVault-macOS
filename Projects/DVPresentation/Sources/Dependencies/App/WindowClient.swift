// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture

@DependencyClient
public struct WindowClient: Sendable {
  public var ensureMainWindowOpen: @Sendable () async -> Void = {}
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
