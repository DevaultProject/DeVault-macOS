// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture
import DVDomain

@DependencyClient
public struct ICloudSettingsClient: Sendable {
  /// iCloud 동기화 사용 여부.
  public var isEnabled: @Sendable () -> Bool = { false }
  /// iCloud 동기화 사용 여부를 저장한다.
  public var setEnabled: @Sendable (Bool) async throws -> Void
  /// iCloud 시스템 설정 패널을 연다.
  public var openSystemSettings: @Sendable () -> Void
  /// 마지막으로 CloudKit 원격 변경이 감지된 시각. 한 번도 없었으면 nil.
  public var lastUpdateDetectedAt: @Sendable () -> Date?
  /// CloudKit 원격 변경이 감지될 때마다 값을 방출한다.
  public var remoteChangeStream: @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
  /// 현재 iCloud 계정 상태.
  public var accountStatus: @Sendable () async -> ICloudAccountStatus = { .couldNotDetermine }
}

extension ICloudSettingsClient: TestDependencyKey {
  public static let testValue = ICloudSettingsClient()

  public static let previewValue = ICloudSettingsClient(
    isEnabled: { false },
    setEnabled: { _ in },
    openSystemSettings: { },
    lastUpdateDetectedAt: { nil },
    remoteChangeStream: { AsyncStream { $0.finish() } },
    accountStatus: { .available }
  )
}

extension DependencyValues {
  public var iCloudSettingsClient: ICloudSettingsClient {
    get { self[ICloudSettingsClient.self] }
    set { self[ICloudSettingsClient.self] = newValue }
  }
}
