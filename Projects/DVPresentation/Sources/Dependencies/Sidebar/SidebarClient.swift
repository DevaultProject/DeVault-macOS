// Copyright © 2026 Devault. All rights reserved

import Foundation

import ComposableArchitecture

@DependencyClient
public struct SidebarClient: Sendable {
  /// 전체 Project 목록을 조회한다.
  public var fetchProjects: @Sendable () async throws -> [ProjectItem]
  /// 새 Project를 만든다.
  public var createProject: @Sendable (_ name: String) async throws -> ProjectItem
  /// Project 이름을 바꾼다.
  public var renameProject: @Sendable (_ id: ProjectItem.ID, _ name: String) async throws -> ProjectItem
  /// Project를 삭제한다.
  public var deleteProject: @Sendable (_ id: ProjectItem.ID) async throws -> Void

  /// 필터 카드·프로젝트 행에 표시할 Secret 개수를 한 번에 조회한다.
  /// - Parameters:
  ///   - referenceDate: Expired 집계 기준 시각. 호출부(Reducer)가 `@Dependency(\.date.now)`로 주입한다
  ///   - projectIDs: 개수를 집계할 프로젝트 ID 목록
  public var fetchCounts: @Sendable (
    _ referenceDate: Date,
    _ projectIDs: [ProjectItem.ID]
  ) async throws -> SecretCounts
}

extension SidebarClient: TestDependencyKey {
  public static let testValue = SidebarClient()

  public static let previewValue = SidebarClient(
    fetchProjects: { ProjectItem.previews },
    createProject: { name in ProjectItem(id: UUID(), name: name) },
    renameProject: { id, name in ProjectItem(id: id, name: name) },
    deleteProject: { _ in },
    fetchCounts: { _, projectIDs in
      SecretCounts(
        byFilter: [.all: 12, .starred: 3, .notice: 2, .expired: 1, .deleted: 4],
        byProject: Dictionary(projectIDs.enumerated().map { ($1, $0 + 1) }, uniquingKeysWith: { first, _ in first })
      )
    }
  )
}

extension DependencyValues {
  public var sidebarClient: SidebarClient {
    get { self[SidebarClient.self] }
    set { self[SidebarClient.self] = newValue }
  }
}
