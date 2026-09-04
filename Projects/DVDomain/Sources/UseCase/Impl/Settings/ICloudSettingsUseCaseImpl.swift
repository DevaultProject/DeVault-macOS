// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct ICloudSettingsUseCaseImpl: ICloudSettingsUseCase {

  private let repository: any SettingsRepository
  private let iCloudService: any ICloudService
  private let entitlementUseCase: any EntitlementUseCase

  /// - Parameters:
  ///   - repository: 설정 저장소
  ///   - iCloudService: 계정 상태 조회와 저장소 구성
  ///   - entitlementUseCase: 동기화 사용 가능 여부 판정. **기본값을 두지 않는다** — 빠뜨리면 가드가 조용히 사라진다
  public init(
    repository: any SettingsRepository,
    iCloudService: any ICloudService,
    entitlementUseCase: any EntitlementUseCase
  ) {
    self.repository = repository
    self.iCloudService = iCloudService
    self.entitlementUseCase = entitlementUseCase
  }

  public func isEnabled() -> Bool {
    repository.isICloudSyncEnabled()
  }

  public func setEnabled(_ enabled: Bool) async throws {
    // 켜는 것만 막는다. 끄는 것은 등급과 무관하게 언제나 허용해야 다운그레이드가 막히지 않는다.
    if enabled, !entitlementUseCase.canEnableICloudSync() {
      throw EntitlementError.requiresPro
    }
    guard enabled else {
      // 끄기는 fail-safe: 전환이 실패해도 플래그를 먼저 false로 확정한다(실패가 "free인데 동기화"로 남지 않게).
      repository.setICloudSyncEnabled(false)
      try await iCloudService.configureStorage(iCloudSyncEnabled: false)
      return
    }
    // 켜기는 fail-secure: 저장소 전환이 성공해야 플래그를 올린다(실패를 켜짐으로 오인 금지).
    try await iCloudService.configureStorage(iCloudSyncEnabled: true)
    repository.setICloudSyncEnabled(true)
  }

  public func accountStatus() async -> ICloudAccountStatus {
    await iCloudService.fetchAccountStatus()
  }

  public func remoteChangeStream() -> AsyncStream<Void> {
    iCloudService.remoteChangeStream()
  }

  public func lastUpdateDetectedAt() -> Date? {
    repository.iCloudLastUpdateDetectedAt()
  }

  public func setLastUpdateDetectedAt(_ date: Date) {
    repository.setICloudLastUpdateDetectedAt(date)
  }
}
