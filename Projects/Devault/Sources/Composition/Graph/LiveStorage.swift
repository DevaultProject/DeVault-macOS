// Copyright © 2026 Devault. All rights reserved

import OSLog

import DVData
import DVDomain

/// 앱에서 사용하는 저장소 구성을 지연 생성하고, iCloud 설정 변경 시 Repository 묶음을 원자적으로 교체한다.
actor LiveStorage {
  private static let logger = Logger(subsystem: "com.devault", category: "LiveStorage")

  private struct RepositorySet {
    let storage: LocalStorage
    let secret: any SecretRepository
    let project: any ProjectRepository
    let dataReset: any DataResetRepository
    let isICloudSyncEnabled: Bool
  }

  private let settingsRepository: any SettingsRepository
  private var current: RepositorySet?

  init(settingsRepository: any SettingsRepository) {
    self.settingsRepository = settingsRepository
  }

  func secretRepository() throws -> any SecretRepository {
    try repositories().secret
  }

  func projectRepository() throws -> any ProjectRepository {
    try repositories().project
  }

  func dataResetRepository() throws -> any DataResetRepository {
    try repositories().dataReset
  }

  /// 새 Repository 묶음 생성에 성공한 경우에만 현재 구성을 교체한다.
  func configure(iCloudSyncEnabled: Bool) throws {
    guard current?.isICloudSyncEnabled != iCloudSyncEnabled else { return }
    current = try makeRepositorySet(iCloudSyncEnabled: iCloudSyncEnabled)
  }
}

extension LiveStorage {
  /// CloudKit 미러링 여부를 판정한다. iCloud 동기화는 Pro 전용이라 free면 항상 false.
  /// 순수 판정만 하고, 플래그 정리는 `setEnabled(false)`가 맡는다.
  static func resolveICloudSync(_ repository: any SettingsRepository) -> Bool {
    repository.isICloudSyncEnabled() && repository.cachedEntitlement() == .pro
  }
}

private extension LiveStorage {
  private func repositories() throws -> RepositorySet {
    if let current { return current }

    let repositorySet = try makeRepositorySet(
      iCloudSyncEnabled: Self.resolveICloudSync(settingsRepository)
    )
    current = repositorySet
    return repositorySet
  }

  private func makeRepositorySet(iCloudSyncEnabled: Bool) throws -> RepositorySet {
    do {
      let storage = try LocalStorage.makeDefault(iCloudSyncEnabled: iCloudSyncEnabled)
      return RepositorySet(
        storage: storage,
        secret: SecretRepositoryImpl(modelContainer: storage.modelContainer),
        project: ProjectRepositoryImpl(modelContainer: storage.modelContainer),
        dataReset: DataResetRepositoryImpl(modelContainer: storage.modelContainer),
        isICloudSyncEnabled: iCloudSyncEnabled
      )
    } catch {
      Self.logger.error(
        "저장소 구성 실패(iCloud: \(iCloudSyncEnabled)): \(error, privacy: .public)"
      )
      throw error
    }
  }
}
